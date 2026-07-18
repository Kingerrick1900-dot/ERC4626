// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Morpho Blue–compatible fixed price oracle for RSS/USDC.
/// Price = loan-units per 1 collateral-wei, scaled by 1e36.
/// At $0.05: 1 RSS (1e18 wei) = 0.05 USDC = 5e4 raw → price = 5e22.
contract MorphoFixedOracle {
    uint256 public priceValue;
    address public owner;

    event PriceUpdated(uint256 price);

    constructor(uint256 initialPrice) {
        owner = msg.sender;
        priceValue = initialPrice;
        emit PriceUpdated(initialPrice);
    }

    function price() external view returns (uint256) {
        return priceValue;
    }

    function setPrice(uint256 newPrice) external {
        require(msg.sender == owner, "OWNER");
        require(newPrice > 0, "ZERO");
        // Soft cap: ≤ $1 per RSS → 1e6 * 1e36 / 1e18 = 1e24
        require(newPrice <= 1e24, "CAP");
        priceValue = newPrice;
        emit PriceUpdated(newPrice);
    }

    function transferOwnership(address n) external {
        require(msg.sender == owner, "OWNER");
        require(n != address(0), "ZERO");
        owner = n;
    }
}
