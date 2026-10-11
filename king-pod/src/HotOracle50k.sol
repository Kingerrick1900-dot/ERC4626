// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "./lib/Core.sol";

interface IZkGateO2 {
    function isProven(address subject) external view returns (bool);
}

interface IBordersO2 {
    function bordersSecure() external view returns (bool);
}

interface IAggregatorV3 {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    function decimals() external view returns (uint8);
}

/// @notice Build 2 — HotOracle50k. Price timelocked 24h. Floor $13.50. Default HOT $50k.
/// @dev LLTV lever is SovereignRailLLTV55 (instant). Oracle price is the slow dial.
contract HotOracle50k is Ownable {
    IZkGateO2 public immutable zkGate;
    IBordersO2 public immutable attest;
    address public immutable king;
    /// @dev Build 1 rail — LLTV lever reference (not called on price path).
    address public immutable sovereignRail;
    IAggregatorV3 public immutable chainlink;

    /// @dev Morpho scale: $50,000 = 5e28 (USDC 6dp / RSS 18dp).
    uint256 public constant KING_50K = 5e28;
    /// @dev Morpho scale: $13.50 = 1.35e25.
    uint256 public constant FLOOR_1350 = 135e23;
    uint256 public constant TIMELOCK = 24 hours;

    uint256 internal _price;
    uint256 public pendingPrice;
    uint256 public priceEta;

    event PriceQueued(uint256 price, uint256 eta);
    event PriceSet(uint256 price);

    error Auth();
    error Zero();
    error Timelock();
    error BelowFloor();
    error NotProven();
    error Borders();

    modifier whenZk() {
        if (!zkGate.isProven(king)) revert NotProven();
        if (!attest.bordersSecure()) revert Borders();
        _;
    }

    constructor(
        address zkGate_,
        address attest_,
        address king_,
        address sovereignRail_,
        address chainlink_,
        address owner_
    ) Ownable(owner_) {
        require(
            zkGate_ != address(0) && attest_ != address(0) && king_ != address(0) && sovereignRail_ != address(0),
            "ZERO"
        );
        zkGate = IZkGateO2(zkGate_);
        attest = IBordersO2(attest_);
        king = king_;
        sovereignRail = sovereignRail_;
        chainlink = IAggregatorV3(chainlink_);
        _price = KING_50K;
    }

    /// @notice Queue a price — applies after 24h. Cannot go below $13.50 floor.
    function setPrice(uint256 newPrice) external whenZk {
        if (msg.sender != owner && msg.sender != king) revert Auth();
        if (newPrice == 0) revert Zero();
        if (newPrice < _floor()) revert BelowFloor();
        pendingPrice = newPrice;
        priceEta = block.timestamp + TIMELOCK;
        emit PriceQueued(newPrice, priceEta);
    }

    /// @notice Finalize queued price after timelock.
    function applyPrice() external whenZk {
        if (msg.sender != owner && msg.sender != king) revert Auth();
        if (pendingPrice == 0 || block.timestamp < priceEta) revert Timelock();
        uint256 p = pendingPrice;
        if (p < _floor()) revert BelowFloor();
        _price = p;
        pendingPrice = 0;
        priceEta = 0;
        emit PriceSet(p);
    }

    /// @notice Live price — never below Chainlink/constant $13.50 floor.
    function getPrice() external view returns (uint256) {
        uint256 p = _price;
        uint256 f = _floor();
        return p < f ? f : p;
    }

    /// @dev Morpho IOracle alias.
    function price() external view returns (uint256) {
        uint256 p = _price;
        uint256 f = _floor();
        return p < f ? f : p;
    }

    function _floor() internal view returns (uint256) {
        uint256 f = FLOOR_1350;
        if (address(chainlink) == address(0)) return f;
        (, int256 answer,, uint256 updatedAt,) = chainlink.latestRoundData();
        if (answer <= 0 || updatedAt == 0 || block.timestamp > updatedAt + 1 days) return f;
        // Chainlink USD 8dp → Morpho scale (USDC6/coll18): usd * 1e6 * 1e36 / 1e18 / 1e8 = usd * 1e16
        uint256 linkMorpho = (uint256(answer) * 1e16);
        // Floor is max(constant $13.50, chainlink-implied floor clamp at $13.50)
        if (linkMorpho < FLOOR_1350) return FLOOR_1350;
        return f;
    }
}
