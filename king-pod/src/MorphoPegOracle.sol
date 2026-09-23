// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MorphoPegOracle
/// @notice Morpho Blue oracle for stable↔stable (or fixed-peg) pairs.
/// @dev price = loanToken units per 1 collateral wei, scaled by 1e36.
///      eUSD(18)/USDC(6) @ $1 → 1e24 · eUSD(18)/DAI(18) @ $1 → 1e36
contract MorphoPegOracle {
    uint256 public priceValue;
    address public owner;

    event PriceUpdated(uint256 price);

    error NotOwner();
    error Zero();

    constructor(uint256 initialPrice) {
        if (initialPrice == 0) revert Zero();
        owner = msg.sender;
        priceValue = initialPrice;
        emit PriceUpdated(initialPrice);
    }

    function price() external view returns (uint256) {
        return priceValue;
    }

    function setPrice(uint256 newPrice) external {
        if (msg.sender != owner) revert NotOwner();
        if (newPrice == 0) revert Zero();
        priceValue = newPrice;
        emit PriceUpdated(newPrice);
    }

    function transferOwnership(address n) external {
        if (msg.sender != owner) revert NotOwner();
        if (n == address(0)) revert Zero();
        owner = n;
    }
}
