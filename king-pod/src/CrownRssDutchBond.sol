// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

/// @notice Dutch RSS bond — price rises over time. Early buyers get deeper discount. USDC → Landing.
/// @dev Spoils engine: creates urgency IN without begging for King USDC.
contract CrownRssDutchBond is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable rss;
    IERC20 public immutable usdc;
    address public immutable king;

    address public landing;
    uint256 public rssForBond;
    uint256 public raisedUsdc;
    uint256 public bondedRss;
    uint256 public phase1TargetUsdc;
    bool public live;

    uint256 public priceFloor; // USDC per 1e18 RSS (e.g. 0.94e6)
    uint256 public priceCeiling; // e.g. 0.99e6 — never above $1 peg
    uint256 public dutchStart;
    uint256 public dutchDuration;

    event DutchArmed(address landing, uint256 floor, uint256 ceiling, uint256 duration, uint256 rssForBond);
    event Bonded(address buyer, uint256 rssOut, uint256 usdcIn, uint256 priceUsed, address landing);
    event Stocked(uint256 rssAdded, uint256 rssForBond);
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
        priceFloor = 0.94e6;
        priceCeiling = 0.99e6;
        dutchDuration = 7 days;
        phase1TargetUsdc = 500_000e6;
    }

    function currentPrice() public view returns (uint256) {
        if (!live || dutchStart == 0) return priceFloor;
        if (block.timestamp >= dutchStart + dutchDuration) return priceCeiling;
        uint256 elapsed = block.timestamp - dutchStart;
        return priceFloor + ((priceCeiling - priceFloor) * elapsed) / dutchDuration;
    }

    function stock(uint256 rssAmt) external onlyOwner nonReentrant {
        if (rssAmt == 0) revert BadAmt();
        rss.safeTransferFrom(msg.sender, address(this), rssAmt);
        rssForBond += rssAmt;
        emit Stocked(rssAmt, rssForBond);
    }

    function armDutch(
        address landing_,
        uint256 floor_,
        uint256 ceiling_,
        uint256 duration_,
        uint256 phase1TargetUsdc_,
        bool live_
    ) external onlyOwner {
        if (landing_ == address(0)) revert BadAmt();
        if (floor_ == 0 || ceiling_ > 1e6 || floor_ > ceiling_) revert BadPrice();
        landing = landing_;
        priceFloor = floor_;
        priceCeiling = ceiling_;
        if (duration_ > 0) dutchDuration = duration_;
        if (phase1TargetUsdc_ > 0) phase1TargetUsdc = phase1TargetUsdc_;
        dutchStart = block.timestamp;
        live = live_;
        emit DutchArmed(landing_, floor_, ceiling_, dutchDuration, rssForBond);
        if (!live_) emit Paused();
    }

    function pause() external onlyOwner {
        live = false;
        emit Paused();
    }

    function bondWithUsdc(uint256 usdcAmt) external nonReentrant returns (uint256 rssAmt) {
        if (!live) revert NotLive();
        if (usdcAmt == 0) revert BadAmt();
        uint256 p = currentPrice();
        rssAmt = (usdcAmt * 1e18) / p;
        if (rssAmt == 0 || rssAmt > rssForBond) revert SoldOut();

        usdc.safeTransferFrom(msg.sender, landing, usdcAmt);
        rssForBond -= rssAmt;
        bondedRss += rssAmt;
        raisedUsdc += usdcAmt;
        rss.safeTransfer(msg.sender, rssAmt);
        emit Bonded(msg.sender, rssAmt, usdcAmt, p, landing);
    }

    function quoteRss(uint256 usdcAmt) external view returns (uint256) {
        return (usdcAmt * 1e18) / currentPrice();
    }

    function phase1RemainingUsdc() external view returns (uint256) {
        if (raisedUsdc >= phase1TargetUsdc) return 0;
        return phase1TargetUsdc - raisedUsdc;
    }
}
