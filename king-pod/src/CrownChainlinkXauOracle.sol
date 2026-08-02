// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Morpho-compatible Chainlink XAU/USD reference oracle for 8dp kXAU / 6dp USDC.
/// @dev Reference only — kingdom GOLD markets use CrownFixedOracle @ $10 unless upgraded.
///      Chainlink Base XAU/USD: 0x5213eBB69743b85644dbB6E25cdF994aFBb8cF31 (8dp answer).
///      Morpho price = answer * 1e26  (usd * 1e34 for 8dp coll).
interface IAggregatorV3 {
    function latestRoundData()
        external
        view
        returns (uint80, int256 answer, uint256, uint256 updatedAt, uint80);
    function decimals() external view returns (uint8);
}

contract CrownChainlinkXauOracle {
    IAggregatorV3 public immutable feed;
    uint256 public immutable maxStale; // seconds

    error BadAnswer();
    error Stale();

    constructor(address feed_, uint256 maxStale_) {
        require(feed_ != address(0), "FEED");
        feed = IAggregatorV3(feed_);
        maxStale = maxStale_ == 0 ? 1 days : maxStale_;
    }

    function price() external view returns (uint256) {
        (, int256 answer,, uint256 updatedAt,) = feed.latestRoundData();
        if (answer <= 0) revert BadAnswer();
        if (block.timestamp > updatedAt + maxStale) revert Stale();
        // answer 8dp USD → Morpho 8dp/6dp scale: usd * 1e34 = answer * 1e26
        return uint256(answer) * 1e26;
    }
}
