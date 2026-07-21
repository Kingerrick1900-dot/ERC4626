// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, ReentrancyGuard} from "./lib/Core.sol";

interface IOpsDesk {
    function buyWithUsdc(uint256 usdcAmt) external returns (uint256 rssAmt);
    function buy(uint256 rssAmt) external;
    function live() external view returns (bool);
    function quoteRss(uint256 usdcAmt) external view returns (uint256);
    function quoteUsdc(uint256 rssAmt) external view returns (uint256);
}

/// @notice Public one-click Phase 1 fill helper — approve this OR desk, then fill.
/// @dev Steakhouse posture: make settlement stupid-easy for capital. No beg UX.
contract CrownDeskFillHelper is ReentrancyGuard {
    using SafeTransfer for IERC20;

    IOpsDesk public immutable desk;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    address public immutable landing;

    event Filled(address indexed buyer, uint256 usdcIn, uint256 rssOut);

    constructor(address desk_, address usdc_, address rss_, address landing_) {
        desk = IOpsDesk(desk_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        landing = landing_;
    }

    /// @notice Pull USDC from buyer, fill desk $500k Phase 1 (or any usdcAmt), return RSS to buyer.
    function fill(uint256 usdcAmt) external nonReentrant returns (uint256 rssOut) {
        require(desk.live(), "NOT_LIVE");
        require(usdcAmt > 0, "AMT");
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmt);
        usdc.safeApprove(address(desk), usdcAmt);
        rssOut = desk.buyWithUsdc(usdcAmt);
        rss.safeTransfer(msg.sender, rssOut);
        emit Filled(msg.sender, usdcAmt, rssOut);
    }

    /// @notice Explicit Phase 1 size — $500,000 USDC.
    function fillPhase1() external nonReentrant returns (uint256 rssOut) {
        uint256 usdcAmt = 500_000e6;
        require(desk.live(), "NOT_LIVE");
        usdc.safeTransferFrom(msg.sender, address(this), usdcAmt);
        usdc.safeApprove(address(desk), usdcAmt);
        rssOut = desk.buyWithUsdc(usdcAmt);
        rss.safeTransfer(msg.sender, rssOut);
        emit Filled(msg.sender, usdcAmt, rssOut);
    }
}
