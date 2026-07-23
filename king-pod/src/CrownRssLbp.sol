// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

/// @notice RSS/USDC Liquidity Bootstrapping Pool — weights 80/20 → 20/80 over `duration`.
/// @dev PCV-seeded. Traders buy RSS with USDC. USDC can settle to Landing (command liquidity).
///      Spot ≈ (usdc/wUsdc) / (rss/wRss) with linear weight shift (Balancer-style intuition).
contract CrownRssLbp is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint256 public constant WAD = 1e18;
    uint256 public constant W_RSS_START = 0.80e18;
    uint256 public constant W_RSS_END = 0.20e18;

    IERC20 public immutable rss;
    IERC20 public immutable usdc;
    address public immutable landing;

    uint256 public rssReserve;
    uint256 public usdcReserve;
    uint64 public startTime;
    uint64 public duration; // e.g. 48 hours
    bool public live;
    uint256 public usdcToLandingBps = 10_000; // 100% of USDC in → Landing (bootstrap capture); pool keeps RSS

    event Seeded(uint256 rssAmt, uint256 usdcAmt, uint64 duration);
    event Bought(address indexed buyer, uint256 usdcIn, uint256 rssOut, uint256 wRss);
    event LiveSet(bool live);

    error BadAmt();
    error NotLive();
    error Empty();

    constructor(address rss_, address usdc_, address landing_, address owner_) Ownable(owner_) {
        rss = IERC20(rss_);
        usdc = IERC20(usdc_);
        landing = landing_;
    }

    function setUsdcToLandingBps(uint256 bps) external onlyOwner {
        if (bps > 10_000) revert BadAmt();
        usdcToLandingBps = bps;
    }

    function setLive(bool v) external onlyOwner {
        live = v;
        emit LiveSet(v);
    }

    /// @notice PCV seed. durationSec e.g. 172800 (48h).
    function seed(uint256 rssAmt, uint256 usdcAmt, uint64 durationSec) external onlyOwner nonReentrant {
        if (rssAmt == 0 || durationSec == 0) revert BadAmt();
        rss.safeTransferFrom(msg.sender, address(this), rssAmt);
        if (usdcAmt > 0) usdc.safeTransferFrom(msg.sender, address(this), usdcAmt);
        rssReserve += rssAmt;
        usdcReserve += usdcAmt;
        startTime = uint64(block.timestamp);
        duration = durationSec;
        live = true;
        emit Seeded(rssAmt, usdcAmt, durationSec);
    }

    function weightRss() public view returns (uint256) {
        if (block.timestamp <= startTime) return W_RSS_START;
        uint256 elapsed = block.timestamp - startTime;
        if (elapsed >= duration) return W_RSS_END;
        // linear: start → end
        uint256 delta = W_RSS_START - W_RSS_END;
        return W_RSS_START - (delta * elapsed) / duration;
    }

    function weightUsdc() public view returns (uint256) {
        return WAD - weightRss();
    }

    /// @notice Spot price USDC (6dp) per 1e18 RSS — scaled 1e6.
    function spotUsdcPerRss() public view returns (uint256) {
        if (rssReserve == 0 || usdcReserve == 0) return 0;
        uint256 wR = weightRss();
        uint256 wU = weightUsdc();
        // (usdc/wU) / (rss/wR) → usdc * wR / (rss * wU) ; adjust decimals: usdc 6, rss 18 → * 1e18
        return (usdcReserve * wR * 1e18) / (rssReserve * wU);
    }

    /// @notice Buy RSS with USDC. Simplified: rssOut = usdcIn * 1e12 * wRss / wUsdc (weight-tilted $1 peg).
    function buyRss(uint256 usdcIn, uint256 minRssOut) external nonReentrant returns (uint256 rssOut) {
        if (!live) revert NotLive();
        if (usdcIn == 0) revert BadAmt();
        uint256 wR = weightRss();
        uint256 wU = weightUsdc();
        // At start wR=0.8 wU=0.2 → buyer gets fewer RSS per USDC (expensive RSS)
        // At end wR=0.2 wU=0.8 → more RSS per USDC (cheaper)
        // rssOut = usdcIn * 1e12 * (wU / wR)  … early: 0.2/0.8=0.25 → 0.25 RSS per $1 (high price)
        // wait: high RSS price means fewer RSS per USDC. Early expensive = small rssOut.
        // price high when wR high: rssOut = usdcIn * 1e12 * wU / wR
        rssOut = (usdcIn * 1e12 * wU) / wR;
        if (rssOut < minRssOut) revert BadAmt();
        if (rssOut > rssReserve) revert Empty();

        usdc.safeTransferFrom(msg.sender, address(this), usdcIn);

        uint256 toLand = (usdcIn * usdcToLandingBps) / 10_000;
        uint256 toPool = usdcIn - toLand;
        if (toLand > 0) usdc.safeTransfer(landing, toLand);
        usdcReserve += toPool;
        rssReserve -= rssOut;
        rss.safeTransfer(msg.sender, rssOut);

        emit Bought(msg.sender, usdcIn, rssOut, wR);
    }

    function rescue(address token, uint256 amt) external onlyOwner {
        IERC20(token).safeTransfer(landing, amt);
    }
}
