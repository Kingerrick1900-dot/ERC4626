// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Fixed RSS/eUSD oracle at $1200 per RSS (Morpho 1e36 scale).
/// @dev 1 RSS (1e18) = 1200 eUSD (1e18) → price = 1200e36.
contract MorphoRssEusdOracle {
    uint256 public immutable priceValue;

    constructor() {
        priceValue = 1200e36;
    }

    function price() external view returns (uint256) {
        return priceValue;
    }
}
