// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "./lib/Core.sol";

interface IZkGateO {
    function isProven(address subject) external view returns (bool);
}

interface IBordersO {
    function bordersSecure() external view returns (bool);
}

/// @notice King oracle with on-chain ZK law on every price write.
contract CrownHotOracle50kZk is Ownable {
    IZkGateO public immutable zkGate;
    IBordersO public immutable attest;

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
    error NotProven();
    error Borders();

    modifier whenZk() {
        if (!zkGate.isProven(msg.sender)) revert NotProven();
        if (!attest.bordersSecure()) revert Borders();
        _;
    }

    constructor(address owner_, address zkGate_, address attest_) Ownable(owner_) {
        require(zkGate_ != address(0) && attest_ != address(0), "ZERO");
        zkGate = IZkGateO(zkGate_);
        attest = IBordersO(attest_);
        _price = KING_50K;
    }

    function setPrice(uint256 newPrice) external onlyOwner whenZk {
        if (newPrice == 0) revert Zero();
        if (floor != 0 && newPrice < floor) revert BelowFloor();
        _price = newPrice;
        emit PriceSet(newPrice);
    }

    function queueFloor(uint256 newFloor) external onlyOwner whenZk {
        pendingFloor = newFloor;
        floorEta = block.timestamp + TIMELOCK;
        emit FloorQueued(newFloor, floorEta);
    }

    function applyFloor() external onlyOwner whenZk {
        if (block.timestamp < floorEta) revert Timelock();
        floor = pendingFloor;
        pendingFloor = 0;
        floorEta = 0;
        if (_price < floor) _price = floor;
        emit FloorSet(floor);
    }

    function price() external view returns (uint256) {
        return _price;
    }
}
