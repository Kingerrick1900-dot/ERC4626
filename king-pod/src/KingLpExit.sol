// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";
import {KingPair} from "./KingPair.sol";
import {KingSusdc} from "./KingSusdc.sol";
import {KingMoneyMarket} from "./KingMoneyMarket.sol";

/// @notice Burns KingPair LP (from market release) → sUSDC → USDC to King.
contract KingLpExit is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    KingMoneyMarket public immutable market;
    KingPair public immutable pair;
    KingSusdc public immutable sUsdc;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    address public king;

    event Exited(uint256 lpBurned, uint256 rssOut, uint256 usdcOut);

    constructor(
        address market_,
        address pair_,
        address sUsdc_,
        address usdc_,
        address rss_,
        address king_,
        address owner_
    ) Ownable(owner_) {
        market = KingMoneyMarket(market_);
        pair = KingPair(pair_);
        sUsdc = KingSusdc(sUsdc_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        king = king_;
    }

    /// @dev Requires market.releaseCollateral on deployed market (owner upgrade) OR V2 market.
    function exitLp(uint256 lpAmount, uint256 minUsdcOut) external onlyOwner nonReentrant {
        require(lpAmount > 0, "ZERO");
        market.releaseCollateral(king, lpAmount, address(this));
        require(pair.transfer(address(pair), lpAmount), "LP");
        (uint256 rssOut, uint256 sOut) = pair.burn(address(this));
        uint256 usdcOut = sUsdc.redeem(sOut, address(this), address(this));
        require(usdcOut >= minUsdcOut, "SLIP");
        usdc.safeTransfer(king, usdcOut);
        if (rssOut > 0) rss.safeTransfer(king, rssOut);
        emit Exited(lpAmount, rssOut, usdcOut);
    }
}
