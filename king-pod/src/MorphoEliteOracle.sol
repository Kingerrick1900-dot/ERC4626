// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Uncapped Morpho-compatible oracle. King sets any price. Soft cap removed (elite).
contract MorphoEliteOracle {
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
        priceValue = newPrice;
        emit PriceUpdated(newPrice);
    }

    function transferOwnership(address n) external {
        require(msg.sender == owner, "OWNER");
        require(n != address(0), "ZERO");
        owner = n;
    }
}
