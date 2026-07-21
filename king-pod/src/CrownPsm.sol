// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

/// @notice 1:1 PSM — USDC in ↔ kUSD out (and redeem kUSD → USDC). Force settlement rail.
/// @dev Stock USDC to enable kUSD→USDC off-ramp. Sell kUSD for USDC at peg without DEX depth.
contract CrownPsm is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable usdc;
    IERC20 public immutable kusd;
    address public immutable king;
    address public landing;

    uint256 public usdcStock;
    uint256 public soldKusd; // kUSD sold for USDC (off-ramp volume)
    uint256 public mintedViaUsdc; // USDC→kUSD volume

    event Stocked(uint256 usdcAmt);
    event Unstocked(uint256 usdcAmt, address to);
    event BuyKusd(address indexed buyer, uint256 usdcIn, uint256 kusdOut);
    event SellKusd(address indexed seller, uint256 kusdIn, uint256 usdcOut);
    event LandingSet(address landing);

    error BadAmt();
    error Empty();

    constructor(address usdc_, address kusd_, address king_, address landing_, address owner_)
        Ownable(owner_)
    {
        usdc = IERC20(usdc_);
        kusd = IERC20(kusd_);
        king = king_;
        landing = landing_;
    }

    function setLanding(address landing_) external onlyOwner {
        if (landing_ == address(0)) revert BadAmt();
        landing = landing_;
        emit LandingSet(landing_);
    }

    /// @notice King stocks USDC so holders can redeem kUSD → USDC (bills off-ramp).
    function stockUsdc(uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0) revert BadAmt();
        usdc.safeTransferFrom(msg.sender, address(this), amt);
        usdcStock += amt;
        emit Stocked(amt);
    }

    function unstockUsdc(uint256 amt, address to) external onlyOwner nonReentrant {
        if (to == address(0)) to = landing;
        if (amt == 0 || amt > usdcStock) revert BadAmt();
        usdcStock -= amt;
        usdc.safeTransfer(to, amt);
        emit Unstocked(amt, to);
    }

    /// @notice Pay USDC, receive kUSD 1:1 from King's inventory (must approve + King pre-approved PSM).
    /// @dev King must transfer kUSD to PSM (or approve) for inventory. Simpler: King calls stockKusd.
    uint256 public kusdStock;

    function stockKusd(uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0) revert BadAmt();
        kusd.safeTransferFrom(msg.sender, address(this), amt);
        kusdStock += amt;
        emit Stocked(amt);
    }

    function unstockKusd(uint256 amt, address to) external onlyOwner nonReentrant {
        if (to == address(0)) to = king;
        if (amt == 0 || amt > kusdStock) revert BadAmt();
        kusdStock -= amt;
        kusd.safeTransfer(to, amt);
        emit Unstocked(amt, to);
    }

    /// @notice USDC → kUSD at $1 (buyer gets kUSD; USDC stays in PSM / can route landing later).
    function buyKusdWithUsdc(uint256 usdcAmt) external nonReentrant {
        if (usdcAmt == 0 || usdcAmt > kusdStock) revert Empty();
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmt);
        usdcStock += usdcAmt;
        kusdStock -= usdcAmt;
        mintedViaUsdc += usdcAmt;
        kusd.safeTransfer(msg.sender, usdcAmt);
        emit BuyKusd(msg.sender, usdcAmt, usdcAmt);
    }

    /// @notice kUSD → USDC at $1 (OFF-RAMP for bills). Requires USDC stock.
    function sellKusdForUsdc(uint256 kusdAmt) external nonReentrant {
        if (kusdAmt == 0 || kusdAmt > usdcStock) revert Empty();
        kusd.safeTransferFrom(msg.sender, address(this), kusdAmt);
        kusdStock += kusdAmt;
        usdcStock -= kusdAmt;
        soldKusd += kusdAmt;
        usdc.safeTransfer(msg.sender, kusdAmt);
        emit SellKusd(msg.sender, kusdAmt, kusdAmt);
    }

    /// @notice Sweep USDC proceeds above keep to Landing (treasury).
    function sweepUsdcToLanding(uint256 keep) external onlyOwner nonReentrant {
        uint256 bal = usdc.balanceOf(address(this));
        if (bal <= keep) return;
        uint256 send = bal - keep;
        if (send > usdcStock) usdcStock = 0;
        else usdcStock -= send;
        usdc.safeTransfer(landing, send);
    }
}
