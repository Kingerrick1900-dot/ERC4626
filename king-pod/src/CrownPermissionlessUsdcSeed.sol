// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

/// @notice Permissionless USDC seed — anyone pays USDC to Landing, receives RSS from escrow.
/// @dev Solves desk-wait failure mode: open fill, not named counterparty.
///      Price: `rssPerUsdc` = RSS (18dp) per 1 USDC (1e6). Default 1e12 = $1 par.
///      Optional discountBps sweetens filler (more RSS per USDC).
///      Elepan never touched.
contract CrownPermissionlessUsdcSeed is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable rss;
    IERC20 public immutable usdc;
    address public immutable landing;
    address public constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;

    /// @notice RSS wei credited per 1 raw USDC unit (6dp). 1e12 => $1 par.
    uint256 public rssPerUsdc = 1e12;
    /// @notice Extra RSS to filler in bps (e.g. 200 = +2% RSS).
    uint256 public sweetenerBps;
    uint256 public constant BPS = 10_000;

    uint256 public rssEscrow;
    uint256 public usdcRaised;
    uint256 public rssSold;
    bool public paused;

    event Seeded(address indexed filler, uint256 usdcIn, uint256 rssOut, address landing);
    event EscrowDeposited(uint256 amt);
    event EscrowWithdrawn(uint256 amt);
    event Params(uint256 rssPerUsdc, uint256 sweetenerBps);
    event Paused(bool paused);

    error Zero();
    error PausedErr();
    error Elepan();
    error Escrow();
    error LandingMiss();

    constructor(address rss_, address usdc_, address landing_, address owner_) Ownable(owner_) {
        require(rss_ != ELEPAN, "ELEPAN");
        require(rss_ != address(0) && usdc_ != address(0) && landing_ != address(0), "ZERO");
        rss = IERC20(rss_);
        usdc = IERC20(usdc_);
        landing = landing_;
    }

    function setParams(uint256 rssPerUsdc_, uint256 sweetenerBps_) external onlyOwner {
        require(rssPerUsdc_ > 0, "PRICE");
        require(sweetenerBps_ <= 2_000, "SWEET"); // max +20%
        rssPerUsdc = rssPerUsdc_;
        sweetenerBps = sweetenerBps_;
        emit Params(rssPerUsdc_, sweetenerBps_);
    }

    function setPaused(bool p) external onlyOwner {
        paused = p;
        emit Paused(p);
    }

    /// @notice King deposits RSS into escrow for open fill.
    function depositRss(uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0) revert Zero();
        rss.safeTransferFrom(msg.sender, address(this), amt);
        rssEscrow += amt;
        emit EscrowDeposited(amt);
    }

    /// @notice Pull unused RSS back to owner.
    function withdrawRss(uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0 || amt > rssEscrow) revert Escrow();
        rssEscrow -= amt;
        rss.safeTransfer(owner, amt);
        emit EscrowWithdrawn(amt);
    }

    function quoteRssOut(uint256 usdcIn) public view returns (uint256) {
        if (usdcIn == 0) return 0;
        uint256 base = usdcIn * rssPerUsdc;
        return base + (base * sweetenerBps) / BPS;
    }

    /// @notice ANYONE: pay `usdcIn` USDC → Landing, receive RSS from escrow.
    function fill(uint256 usdcIn) external nonReentrant returns (uint256 rssOut) {
        if (paused) revert PausedErr();
        if (usdcIn == 0) revert Zero();
        rssOut = quoteRssOut(usdcIn);
        if (rssOut > rssEscrow) revert Escrow();

        uint256 before = usdc.balanceOf(landing);
        usdc.safeTransferFrom(msg.sender, landing, usdcIn);
        if (usdc.balanceOf(landing) < before + usdcIn) revert LandingMiss();

        rssEscrow -= rssOut;
        rssSold += rssOut;
        usdcRaised += usdcIn;
        rss.safeTransfer(msg.sender, rssOut);
        emit Seeded(msg.sender, usdcIn, rssOut, landing);
    }

    /// @notice Fill max possible for filler's USDC budget (capped by escrow).
    function fillMax(uint256 usdcBudget) external nonReentrant returns (uint256 usdcIn, uint256 rssOut) {
        if (paused) revert PausedErr();
        if (usdcBudget == 0 || rssEscrow == 0) revert Zero();
        // usdc needed for full escrow at current quote
        uint256 unit = rssPerUsdc + (rssPerUsdc * sweetenerBps) / BPS;
        if (unit == 0) revert Zero();
        uint256 maxUsdc = rssEscrow / unit;
        usdcIn = usdcBudget < maxUsdc ? usdcBudget : maxUsdc;
        if (usdcIn == 0) revert Escrow();
        rssOut = quoteRssOut(usdcIn);
        if (rssOut > rssEscrow) {
            // trim dust
            usdcIn = rssEscrow / unit;
            rssOut = quoteRssOut(usdcIn);
        }
        require(rssOut <= rssEscrow && usdcIn > 0, "ESCROW");

        uint256 before = usdc.balanceOf(landing);
        usdc.safeTransferFrom(msg.sender, landing, usdcIn);
        if (usdc.balanceOf(landing) < before + usdcIn) revert LandingMiss();

        rssEscrow -= rssOut;
        rssSold += rssOut;
        usdcRaised += usdcIn;
        rss.safeTransfer(msg.sender, rssOut);
        emit Seeded(msg.sender, usdcIn, rssOut, landing);
    }
}
