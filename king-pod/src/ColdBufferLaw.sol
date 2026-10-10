// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer} from "./lib/Core.sol";

/// @title ColdBufferLaw — 30% of all AMO rewards route to ColdBuffer. No exceptions.
/// @notice minBufferBps = 3000 enforced at protocol level in every AMO reward path.

interface IColdBufferFund {
    function fund(uint256 amount) external;
}

abstract contract ColdBufferLaw {
    using SafeTransfer for IERC20;

    uint256 public constant minBufferBps = 3000; // 30% — immutable law
    IColdBufferFund public immutable coldBuffer;
    IERC20 public immutable rewardToken; // USDC (or AMO reward asset)

    event BufferRouted(address indexed amo, uint256 total, uint256 buffered, uint256 distributable);

    error ColdFloor();

    constructor(address coldBuffer_, address rewardToken_) {
        require(coldBuffer_ != address(0) && rewardToken_ != address(0), "ZERO");
        coldBuffer = IColdBufferFund(coldBuffer_);
        rewardToken = IERC20(rewardToken_);
    }

    /// @notice Call inside every reward/fee collection path while tokens sit on this contract.
    /// @dev Splits 30% → ColdBuffer.fund; returns remaining 70% still on this contract.
    function _routeRewards(uint256 totalRewards) internal returns (uint256 distributable) {
        if (totalRewards == 0) return 0;
        uint256 toBuffer = (totalRewards * minBufferBps) / 10_000;
        // Law: floor cannot be undercut by inheritance tricks (constant enforces).
        if (minBufferBps < 3000) revert ColdFloor();
        distributable = totalRewards - toBuffer;
        if (toBuffer > 0) {
            rewardToken.safeApprove(address(coldBuffer), 0);
            rewardToken.safeApprove(address(coldBuffer), toBuffer);
            coldBuffer.fund(toBuffer);
        }
        emit BufferRouted(address(this), totalRewards, toBuffer, distributable);
    }
}
