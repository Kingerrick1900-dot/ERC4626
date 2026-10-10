// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MintGate — clean readable mint authority surface
/// @notice Ships at unlocked = 0, canMint = false. Only King unlocks tranches.

contract MintGate {
    address public king;
    uint256 public unlocked;
    bool public canMintFlag;

    event TrancheUnlocked(uint256 amount, uint256 timestamp);
    event Locked(uint256 timestamp);
    event KingSet(address indexed king);

    error KingOnly();

    modifier onlyKing() {
        if (msg.sender != king) revert KingOnly();
        _;
    }

    constructor(address king_) {
        require(king_ != address(0), "ZERO");
        king = king_;
        unlocked = 0;
        canMintFlag = false;
    }

    /// @notice Clean readable surface for scoreboard / auditors.
    function canMint() external view returns (bool) {
        return canMintFlag && unlocked > 0;
    }

    function unlockTranche(uint256 amount) external onlyKing {
        require(amount > 0, "ZERO");
        unlocked += amount;
        canMintFlag = true;
        emit TrancheUnlocked(amount, block.timestamp);
    }

    function lockAll() external onlyKing {
        unlocked = 0;
        canMintFlag = false;
        emit Locked(block.timestamp);
    }

    function transferKing(address next) external onlyKing {
        require(next != address(0), "ZERO");
        king = next;
        emit KingSet(next);
    }
}
