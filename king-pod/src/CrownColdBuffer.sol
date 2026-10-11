// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

/// @notice 30% cold redemption buffer — USDC only out via redemption / LSR path.
/// @dev Law: while balance > 0, owner must not pause external redemptions (off-chain+agent law).
contract CrownColdBuffer is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable usdc;
    address public redemptionSink; // LSR or redeem router
    uint256 public minBufferBps = 3000; // 30% target vs redeemable window (informational)
    bool public outflowArmed;

    event Funded(address indexed from, uint256 amount);
    event RedemptionSinkSet(address indexed sink);
    event Outflow(address indexed to, uint256 amount, bytes32 indexed reason);
    event OutflowArmed(bool armed);

    error BadSink();
    error NotArmed();
    error Zero();

    constructor(address usdc_, address owner_, address sink_) Ownable(owner_) {
        usdc = IERC20(usdc_);
        if (sink_ != address(0)) redemptionSink = sink_;
    }

    function setRedemptionSink(address sink) external onlyOwner {
        redemptionSink = sink;
        emit RedemptionSinkSet(sink);
    }

    function setMinBufferBps(uint256 bps) external onlyOwner {
        require(bps <= 10_000, "BPS");
        minBufferBps = bps;
    }

    function armOutflow(bool armed) external onlyOwner {
        outflowArmed = armed;
        emit OutflowArmed(armed);
    }

    function fund(uint256 amount) external nonReentrant {
        if (amount == 0) revert Zero();
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        emit Funded(msg.sender, amount);
    }

    /// @notice Push USDC to sink for live redemptions only.
    function releaseToSink(uint256 amount, bytes32 reason) external onlyOwner nonReentrant {
        if (!outflowArmed) revert NotArmed();
        address sink = redemptionSink;
        if (sink == address(0)) revert BadSink();
        if (amount == 0) revert Zero();
        usdc.safeTransfer(sink, amount);
        emit Outflow(sink, amount, reason);
    }

    function balance() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }

    /// @notice True if cold USDC >= bps of `redeemableWindow` (6dp USDC).
    function meetsRatio(uint256 redeemableWindow) external view returns (bool) {
        if (redeemableWindow == 0) return usdc.balanceOf(address(this)) > 0;
        return usdc.balanceOf(address(this)) * 10_000 >= redeemableWindow * minBufferBps;
    }
}
