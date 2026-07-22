// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IUniswapV3PoolOracle, FullMath} from "./MorphoUniV3Oracle.sol";

/// @notice Morpho IOracle: RSS @ Fixed $1 USD, loan (WETH/cbBTC) via UniV3 loan/USDC TWAP.
/// @dev price = loan-raw per 1 collateral-wei, scaled by 1e36 (Morpho).
contract MorphoFixedRssLoanOracle {
    uint256 public constant RSS_USD_6 = 1e6; // $1 in USDC raw

    IUniswapV3PoolOracle public immutable pool;
    uint32 public immutable twapSeconds;
    bool public immutable loanIsToken0;
    uint8 public immutable loanDecimals;
    address public immutable loan;
    address public immutable usdc;

    error TwapTooShort();
    error BadTokens();
    error BadPrice();

    constructor(address pool_, address loan_, address usdc_, uint32 twapSeconds_, uint8 loanDecimals_) {
        require(twapSeconds_ > 0, "TWAP0");
        pool = IUniswapV3PoolOracle(pool_);
        twapSeconds = twapSeconds_;
        loan = loan_;
        usdc = usdc_;
        loanDecimals = loanDecimals_;

        address t0 = IUniswapV3PoolOracle(pool_).token0();
        address t1 = IUniswapV3PoolOracle(pool_).token1();
        bool isT0;
        if (loan_ == t0 && usdc_ == t1) {
            isT0 = true;
        } else if (loan_ == t1 && usdc_ == t0) {
            isT0 = false;
        } else {
            revert BadTokens();
        }
        loanIsToken0 = isT0;
    }

    /// @notice Morpho scale: (coll * price) / 1e36 = loan raw.
    function price() external view returns (uint256) {
        uint256 usdcPer1Loan = _usdcRawPer1Loan();
        if (usdcPer1Loan == 0) revert BadPrice();
        // loan raw for 1e18 RSS ($1): 1e6 * 10**loanDec / usdcPer1Loan
        // price = that * 1e36 / 1e18
        return FullMath.mulDiv(RSS_USD_6 * (10 ** uint256(loanDecimals)), 1e18, usdcPer1Loan);
    }

    function _usdcRawPer1Loan() internal view returns (uint256) {
        int24 avgTick = _twapTick();
        uint160 sqrtPriceX96 = _getSqrtRatioAtTick(avgTick);
        uint256 ratioX192 = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);
        uint256 baseAmount = 10 ** uint256(loanDecimals);

        if (loanIsToken0) {
            return FullMath.mulDiv(ratioX192, baseAmount, 1 << 192);
        } else {
            return FullMath.mulDiv(1 << 192, baseAmount, ratioX192);
        }
    }

    function _twapTick() internal view returns (int24) {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = twapSeconds;
        secondsAgos[1] = 0;
        (int56[] memory tickCumulatives,) = pool.observe(secondsAgos);
        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
        int56 twap = int56(uint56(twapSeconds));
        int56 avg = tickCumulativesDelta / twap;
        if (tickCumulativesDelta < 0 && (tickCumulativesDelta % twap != 0)) {
            avg -= 1;
        }
        return int24(avg);
    }

    function _getSqrtRatioAtTick(int24 tick) internal pure returns (uint160 sqrtPriceX96) {
        unchecked {
            uint256 absTick = tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick));
            require(absTick <= uint256(int256(887272)), "T");

            uint256 ratio = absTick & 0x1 != 0
                ? 0xfffcb933bd6fad37aa2d162d1a594001
                : 0x100000000000000000000000000000000;
            if (absTick & 0x2 != 0) ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
            if (absTick & 0x4 != 0) ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
            if (absTick & 0x8 != 0) ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
            if (absTick & 0x10 != 0) ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128;
            if (absTick & 0x20 != 0) ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
            if (absTick & 0x40 != 0) ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
            if (absTick & 0x80 != 0) ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
            if (absTick & 0x100 != 0) ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
            if (absTick & 0x200 != 0) ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
            if (absTick & 0x400 != 0) ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
            if (absTick & 0x800 != 0) ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
            if (absTick & 0x1000 != 0) ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
            if (absTick & 0x2000 != 0) ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
            if (absTick & 0x4000 != 0) ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
            if (absTick & 0x8000 != 0) ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
            if (absTick & 0x10000 != 0) ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
            if (absTick & 0x20000 != 0) ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
            if (absTick & 0x40000 != 0) ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
            if (absTick & 0x80000 != 0) ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

            if (tick > 0) ratio = type(uint256).max / ratio;
            sqrtPriceX96 = uint160((ratio >> 32) + (ratio % (1 << 32) == 0 ? 0 : 1));
        }
    }
}
