// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";

interface IPrimeCreditFeed {
    function supply(uint256 amt) external;
    function supplyFrom(address from, uint256 amt) external;
}

/// @title CrownLitePsm
/// @notice LitePSM pocket: pre-minted eUSD/gUSD sell buffer + USDC inbound → credit idle.
/// @dev sellGem (USDC→eUSD) creates real USDC depth. buyGem (eUSD→USDC) is thin exit rail.
///      Optional auto-route of inbound USDC into CrownPrimeCredit (idle engineering).
contract CrownLitePsm is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable eusd;
    IERC20 public immutable usdc;
    address public credit; // CrownPrimeCredit — optional feed target
    bool public autoFeedCredit = true;

    /// @notice Target unused eUSD buffer (18dp), Maker-style buf.
    uint256 public buf;
    uint256 public tin; // fee on sellGem (USDC→eUSD), WAD
    uint256 public tout; // fee on buyGem (eUSD→USDC), WAD
    uint256 public constant WAD = 1e18;

    event BufSet(uint256 buf);
    event FeesSet(uint256 tin, uint256 tout);
    event CreditSet(address credit, bool autoFeed);
    event SellGem(address indexed user, uint256 usdcIn, uint256 eusdOut);
    event BuyGem(address indexed user, uint256 eusdIn, uint256 usdcOut);
    event SeededEusd(uint256 amt);
    event SeededUsdc(uint256 amt);
    event FedCredit(uint256 amt);

    error BadAmt();
    error Dry();
    error NoCredit();

    constructor(address eusd_, address usdc_, address owner_) Ownable(owner_) {
        require(eusd_ != address(0) && usdc_ != address(0), "ZERO");
        eusd = IERC20(eusd_);
        usdc = IERC20(usdc_);
    }

    function setBuf(uint256 buf_) external onlyOwner {
        buf = buf_;
        emit BufSet(buf_);
    }

    function setFees(uint256 tin_, uint256 tout_) external onlyOwner {
        require(tin_ < WAD && tout_ < WAD, "FEE");
        tin = tin_;
        tout = tout_;
        emit FeesSet(tin_, tout_);
    }

    function setCredit(address credit_, bool autoFeed) external onlyOwner {
        credit = credit_;
        autoFeedCredit = autoFeed;
        emit CreditSet(credit_, autoFeed);
    }

    function eusdReserve() public view returns (uint256) {
        return eusd.balanceOf(address(this));
    }

    function usdcReserve() public view returns (uint256) {
        return usdc.balanceOf(address(this));
    }

    /// @notice King seeds pre-minted eUSD sell-side buffer (LitePSM door open).
    function seedEusd(uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0) revert BadAmt();
        eusd.safeTransferFrom(msg.sender, address(this), amt);
        emit SeededEusd(amt);
    }

    function seedUsdc(uint256 amt) external onlyOwner nonReentrant {
        if (amt == 0) revert BadAmt();
        usdc.safeTransferFrom(msg.sender, address(this), amt);
        emit SeededUsdc(amt);
    }

    /// @notice USDC → eUSD (1:1 minus tin). Creates inbound dollars; optionally feeds credit idle.
    function sellGem(uint256 usdcAmt, address to) external nonReentrant returns (uint256 eusdOut) {
        if (usdcAmt == 0) revert BadAmt();
        if (to == address(0)) to = msg.sender;
        // usdc 6dp → eusd 18dp
        uint256 eusdGross = usdcAmt * 1e12;
        eusdOut = eusdGross - (eusdGross * tin) / WAD;
        if (eusdOut > eusdReserve()) revert Dry();

        usdc.safeTransferFrom(msg.sender, address(this), usdcAmt);
        eusd.safeTransfer(to, eusdOut);
        emit SellGem(msg.sender, usdcAmt, eusdOut);

        if (autoFeedCredit && credit != address(0)) {
            _feedCredit(usdcAmt);
        }
    }

    /// @notice eUSD → USDC thin exit (1:1 minus tout). Needs USDC inventory.
    function buyGem(uint256 eusdAmt, address to) external nonReentrant returns (uint256 usdcOut) {
        if (eusdAmt == 0) revert BadAmt();
        if (to == address(0)) to = msg.sender;
        uint256 usdcGross = eusdAmt / 1e12;
        usdcOut = usdcGross - (usdcGross * tout) / WAD;
        if (usdcOut == 0 || usdcOut > usdcReserve()) revert Dry();

        eusd.safeTransferFrom(msg.sender, address(this), eusdAmt);
        usdc.safeTransfer(to, usdcOut);
        emit BuyGem(msg.sender, eusdAmt, usdcOut);
    }

    /// @notice Permissionless: push PSM USDC inventory into credit as lasting idle.
    function feedCredit(uint256 amt) external nonReentrant {
        if (credit == address(0)) revert NoCredit();
        if (amt == 0 || amt > usdcReserve()) revert BadAmt();
        _feedCredit(amt);
    }

    function _feedCredit(uint256 amt) internal {
        usdc.safeApprove(credit, 0);
        usdc.safeApprove(credit, amt);
        IPrimeCreditFeed(credit).supply(amt);
        emit FedCredit(amt);
    }
}
