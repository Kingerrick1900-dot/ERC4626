// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, Ownable} from "./lib/Core.sol";
import {KingPair} from "./KingPair.sol";
import {KingSusdc} from "./KingSusdc.sol";

/// @notice Crown policy oracle: RSS @ $0.05 fixed; sUSDC via convertToAssets; LP = reserve sum.
contract KingOracle is Ownable {
    IERC20 public immutable rss;
    KingSusdc public immutable sUsdc;
    KingPair public immutable pair;

    /// @dev USD price of 1 RSS in 1e18 (0.05e18 = $0.05).
    uint256 public rssPriceUsd1e18 = 0.05e18;
    uint256 public constant USD_1E18 = 1e18;

    constructor(address rss_, address sUsdc_, address pair_, address owner_) Ownable(owner_) {
        rss = IERC20(rss_);
        sUsdc = KingSusdc(sUsdc_);
        pair = KingPair(pair_);
    }

    function setRssPrice(uint256 price1e18) external onlyOwner {
        require(price1e18 > 0 && price1e18 <= 1e18, "PRICE"); // hard cap $1
        rssPriceUsd1e18 = price1e18;
    }

    /// @return usd1e18 value of `lpAmount` LP tokens.
    function lpValueUsd(uint256 lpAmount) public view returns (uint256) {
        uint256 supply = pair.totalSupply();
        if (supply == 0 || lpAmount == 0) return 0;
        (uint256 r0, uint256 r1) = pair.getReserves();
        // token0 = RSS (18), token1 = sUSDC (USDC decimals)
        uint256 rssAmt = (r0 * lpAmount) / supply;
        uint256 sAmt = (r1 * lpAmount) / supply;
        uint256 rssUsd = (rssAmt * rssPriceUsd1e18) / 1e18; // 1e18 USD units (wei-like)
        uint256 usdcAssets = sUsdc.convertToAssets(sAmt);
        // USDC has 6 decimals → scale to 1e18 USD
        uint256 usdcUsd = usdcAssets * 1e12;
        return rssUsd + usdcUsd;
    }
}
