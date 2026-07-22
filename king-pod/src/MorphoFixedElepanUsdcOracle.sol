// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Immutable Morpho IOracle: Elepan (8dp) @ soft $1 vs USDC (6dp).
/// @dev price = 1e6 * 1e36 / 1e8 = 1e34. Owned niche — no Chainlink herd.
contract MorphoFixedElepanUsdcOracle {
    uint256 public constant PRICE = 1e34;

    function price() external pure returns (uint256) {
        return PRICE;
    }
}
