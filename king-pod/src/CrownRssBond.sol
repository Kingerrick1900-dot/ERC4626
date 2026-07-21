// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

/// @notice RSS BOND — token-as-capital. Sell RSS for USDC at discount → Landing.
/// @dev Protocols without USDC treasuries bonded their token. Kingdom does the same.
///      NOT deployed until King OK (LIVE-FIRE-LAW).
///      priceUsdcPerRss < 1e6 = discount to Morpho $1 oracle (e.g. 0.97e6 = $0.97).
contract CrownRssBond is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable rss;
    IERC20 public immutable usdc;
    address public immutable king;

    address public landing;
    uint256 public priceUsdcPerRss; // USDC raw per 1e18 RSS
    uint256 public rssForBond; // inventory
    uint256 public raisedUsdc;
    uint256 public bondedRss;
    uint256 public phase1TargetUsdc; // e.g. 500_000e6
    bool public live;

    event BondArmed(address landing, uint256 priceUsdcPerRss, uint256 rssForBond, uint256 phase1TargetUsdc);
    event Bonded(address buyer, uint256 rssOut, uint256 usdcIn, address landing);
    event Stocked(uint256 rssAdded, uint256 rssForBond);
    event Unstocked(uint256 rssOut, address to);
    event Paused();

    error NotLive();
    error BadAmt();
    error BadPrice();
    error SoldOut();

    constructor(address rss_, address usdc_, address king_, address owner_) Ownable(owner_) {
        rss = IERC20(rss_);
        usdc = IERC20(usdc_);
        king = king_;
        landing = king_;
        priceUsdcPerRss = 0.97e6; // default $0.97 — urgency vs $1 desk
        phase1TargetUsdc = 500_000e6;
    }

    function stock(uint256 rssAmt) external onlyOwner nonReentrant {
        if (rssAmt == 0) revert BadAmt();
        rss.safeTransferFrom(msg.sender, address(this), rssAmt);
        rssForBond += rssAmt;
        emit Stocked(rssAmt, rssForBond);
    }

    function arm(address landing_, uint256 priceUsdcPerRss_, uint256 phase1TargetUsdc_, bool live_)
        external
        onlyOwner
    {
        if (landing_ == address(0)) revert BadAmt();
        if (priceUsdcPerRss_ == 0 || priceUsdcPerRss_ > 1e6) revert BadPrice(); // never above $1 peg
        landing = landing_;
        priceUsdcPerRss = priceUsdcPerRss_;
        if (phase1TargetUsdc_ > 0) phase1TargetUsdc = phase1TargetUsdc_;
        live = live_;
        emit BondArmed(landing_, priceUsdcPerRss_, rssForBond, phase1TargetUsdc);
        if (!live_) emit Paused();
    }

    function pause() external onlyOwner {
        live = false;
        emit Paused();
    }

    /// @notice Bond: pay USDC, receive RSS at discount. USDC → Landing.
    function bond(uint256 rssAmt) external nonReentrant {
        if (!live) revert NotLive();
        if (rssAmt == 0) revert BadAmt();
        if (rssAmt > rssForBond) revert SoldOut();

        uint256 usdcIn = (rssAmt * priceUsdcPerRss) / 1e18;
        if (usdcIn == 0) revert BadAmt();

        usdc.safeTransferFrom(msg.sender, landing, usdcIn);
        rssForBond -= rssAmt;
        bondedRss += rssAmt;
        raisedUsdc += usdcIn;
        rss.safeTransfer(msg.sender, rssAmt);

        emit Bonded(msg.sender, rssAmt, usdcIn, landing);
    }

    /// @notice Bond exact USDC spend (Phase 1 helper).
    function bondWithUsdc(uint256 usdcAmt) external nonReentrant returns (uint256 rssAmt) {
        if (!live) revert NotLive();
        if (usdcAmt == 0) revert BadAmt();
        rssAmt = (usdcAmt * 1e18) / priceUsdcPerRss;
        if (rssAmt == 0) revert BadAmt();
        if (rssAmt > rssForBond) revert SoldOut();

        usdc.safeTransferFrom(msg.sender, landing, usdcAmt);
        rssForBond -= rssAmt;
        bondedRss += rssAmt;
        raisedUsdc += usdcAmt;
        rss.safeTransfer(msg.sender, rssAmt);

        emit Bonded(msg.sender, rssAmt, usdcAmt, landing);
    }

    function unstock(uint256 rssAmt, address to) external onlyOwner nonReentrant {
        if (to == address(0)) to = king;
        if (rssAmt == 0 || rssAmt > rssForBond) revert BadAmt();
        rssForBond -= rssAmt;
        rss.safeTransfer(to, rssAmt);
        emit Unstocked(rssAmt, to);
    }

    function phase1RemainingUsdc() external view returns (uint256) {
        if (raisedUsdc >= phase1TargetUsdc) return 0;
        return phase1TargetUsdc - raisedUsdc;
    }

    function quoteUsdc(uint256 rssAmt) external view returns (uint256) {
        return (rssAmt * priceUsdcPerRss) / 1e18;
    }

    function quoteRss(uint256 usdcAmt) external view returns (uint256) {
        return (usdcAmt * 1e18) / priceUsdcPerRss;
    }
}
