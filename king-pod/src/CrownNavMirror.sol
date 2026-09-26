// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "./lib/Core.sol";

/// @notice Mirrors Base yRSS NAV for ZK attest on expansion chains (Polygon / Scroll).
contract CrownNavMirror is Ownable {
    uint256 public totalAssets;
    bytes32 public sourceVault; // Base yRSS id/address hashed
    uint256 public updatedAt;

    event NavUpdated(uint256 assets, bytes32 sourceVault, uint256 ts);

    constructor(address owner_, uint256 initialNav, bytes32 source_) Ownable(owner_) {
        totalAssets = initialNav;
        sourceVault = source_;
        updatedAt = block.timestamp;
        emit NavUpdated(initialNav, source_, block.timestamp);
    }

    function setNav(uint256 assets, bytes32 source_) external onlyOwner {
        totalAssets = assets;
        sourceVault = source_;
        updatedAt = block.timestamp;
        emit NavUpdated(assets, source_, block.timestamp);
    }
}
