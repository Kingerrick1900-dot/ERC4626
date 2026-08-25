// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Fixed Morpho oracle — configurable RSS/$ price (1e36 scale).
/// @dev V4 step-up: $50_000 per RSS after gUSD brand lands. Kingdom-owned price.
contract MorphoRssOracle {
    uint256 public immutable priceValue;
    uint256 public immutable dollarsPerRss;

    constructor(uint256 dollarsPerRss_) {
        require(dollarsPerRss_ > 0, "ZERO");
        dollarsPerRss = dollarsPerRss_;
        priceValue = dollarsPerRss_ * 1e36;
    }

    function price() external view returns (uint256) {
        return priceValue;
    }
}
