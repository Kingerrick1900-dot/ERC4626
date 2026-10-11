// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "./lib/Core.sol";

/// @notice King oracle: HOT-set primary with optional floor and 24h timelock on floor raises.
/// @dev Morpho scale: $50,000 RSS = 5e28 (USDC 6dp / RSS 18dp). Floor blocks flash crashes.
contract CrownHotOracle50k is Ownable {
    uint256 internal _price;
    uint256 public floor;
    uint256 public pendingFloor;
    uint256 public floorEta;
    uint256 public constant TIMELOCK = 24 hours;
    uint256 public constant KING_50K = 5e28;

    event PriceSet(uint256 price);
    event FloorQueued(uint256 floor, uint256 eta);
    event FloorSet(uint256 floor);

    error Timelock();
    error BelowFloor();
    error Zero();

    constructor(address owner_) Ownable(owner_) {
        _price = KING_50K;
    }

    function setPrice(uint256 newPrice) external onlyOwner {
        if (newPrice == 0) revert Zero();
        if (floor != 0 && newPrice < floor) revert BelowFloor();
        _price = newPrice;
        emit PriceSet(newPrice);
    }

    function queueFloor(uint256 newFloor) external onlyOwner {
        pendingFloor = newFloor;
        floorEta = block.timestamp + TIMELOCK;
        emit FloorQueued(newFloor, floorEta);
    }

    function applyFloor() external onlyOwner {
        if (block.timestamp < floorEta) revert Timelock();
        floor = pendingFloor;
        pendingFloor = 0;
        floorEta = 0;
        if (_price < floor) _price = floor;
        emit FloorSet(floor);
    }

    /// @dev Morpho IOracle
    function price() external view returns (uint256) {
        return _price;
    }
}
