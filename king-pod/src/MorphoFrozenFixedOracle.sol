// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Frozen Morpho Blue fixed oracle — price set once at deploy, no admin.
/// @dev Morpho scale: loan-token units per 1 collateral-wei, × 1e36 normalization.
///      RSS (18dp) / USDC (6dp): $1 → 1e24 · $1200 → 1200e24 = 1.2e27.
///      Elepan never referenced.
contract MorphoFrozenFixedOracle {
    uint256 public immutable priceValue;

    constructor(uint256 price_) {
        require(price_ > 0, "ZERO");
        priceValue = price_;
    }

    function price() external view returns (uint256) {
        return priceValue;
    }
}
