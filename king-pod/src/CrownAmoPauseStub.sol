// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal IAMOPausable for CircuitBreaker registration until AMOs inherit pause.
contract CrownAmoPauseStub {
    address public king;
    bool public paused;

    event EmergencyPaused(uint256 timestamp);

    constructor(address king_) {
        king = king_;
    }

    function emergencyPause() external {
        paused = true;
        emit EmergencyPaused(block.timestamp);
    }

    function unpause() external {
        require(msg.sender == king, "KING");
        paused = false;
    }
}
