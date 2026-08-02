// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IYrssWhale {
    function totalAssets() external view returns (uint256);
    function deposit(uint256 assets, address receiver) external returns (uint256);
}

/// @notice FIRST WHALE facility — rebate RSS to the depositor who creates USDC face on yRSS.
/// @dev NOT deployed until King OK. Steakhouse posture: engineer supply whale with incentive.
///      Whale deposits USDC via this contract into yRSS; when cumulative >= threshold,
///      whale may claim RSS rebate (King-funded inventory). Kingdom then borrows idle → Landing.
contract CrownFirstWhale is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    IYrssWhale public immutable yrss;
    address public immutable king;

    uint256 public thresholdUsdc; // e.g. 500_000e6
    uint256 public rebateRss; // e.g. 50_000 ether — set by stocking
    uint256 public depositedUsdc;
    address public whale;
    bool public rebateClaimed;
    bool public live;

    event Armed(uint256 thresholdUsdc, uint256 rebateBudget);
    event WhaleDeposited(address indexed who, uint256 usdcAmt, uint256 total);
    event RebateClaimed(address indexed whale, uint256 rssAmt);
    event Unstocked(uint256 rssAmt, address to);

    error NotLive();
    error BadAmt();
    error Threshold();
    error NoWhale();
    error Done();

    constructor(address usdc_, address rss_, address yrss_, address king_, address owner_) Ownable(owner_) {
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        yrss = IYrssWhale(yrss_);
        king = king_;
        thresholdUsdc = 500_000e6;
    }

    function arm(uint256 thresholdUsdc_, bool live_) external onlyOwner {
        if (thresholdUsdc_ == 0) revert BadAmt();
        thresholdUsdc = thresholdUsdc_;
        live = live_;
        emit Armed(thresholdUsdc_, rss.balanceOf(address(this)));
    }

    /// @notice King stocks RSS rebate budget into this facility.
    function stockRebate(uint256 rssAmt) external onlyOwner nonReentrant {
        if (rssAmt == 0) revert BadAmt();
        rss.safeTransferFrom(msg.sender, address(this), rssAmt);
        rebateRss += rssAmt;
        emit Armed(thresholdUsdc, rebateRss);
    }

    function unstockRebate(uint256 rssAmt, address to) external onlyOwner nonReentrant {
        if (to == address(0)) to = king;
        if (rssAmt == 0 || rssAmt > rebateRss) revert BadAmt();
        rebateRss -= rssAmt;
        rss.safeTransfer(to, rssAmt);
        emit Unstocked(rssAmt, to);
    }

    /// @notice Whale path: pull USDC → deposit yRSS to whale → count toward threshold.
    function depositAsWhale(uint256 usdcAmt) external nonReentrant {
        if (!live) revert NotLive();
        if (usdcAmt == 0) revert BadAmt();
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmt);
        usdc.safeApprove(address(yrss), usdcAmt);
        yrss.deposit(usdcAmt, msg.sender);
        depositedUsdc += usdcAmt;
        if (whale == address(0)) whale = msg.sender;
        emit WhaleDeposited(msg.sender, usdcAmt, depositedUsdc);
    }

    /// @notice After threshold, designated whale claims RSS rebate once.
    function claimRebate() external nonReentrant {
        if (rebateClaimed) revert Done();
        if (depositedUsdc < thresholdUsdc) revert Threshold();
        if (msg.sender != whale) revert NoWhale();
        uint256 amt = rebateRss;
        if (amt == 0) revert BadAmt();
        rebateRss = 0;
        rebateClaimed = true;
        rss.safeTransfer(msg.sender, amt);
        emit RebateClaimed(msg.sender, amt);
    }

    function rebateBudget() external view returns (uint256) {
        return rss.balanceOf(address(this));
    }
}
