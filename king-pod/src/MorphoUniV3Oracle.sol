// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal Uniswap V3 pool surface for TWAP reads.
interface IUniswapV3PoolOracle {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );
}

/// @notice Morpho Blue IOracle quoting UniV3 TWAP of collateral/loan pool.
/// @dev price = loan-units per 1 collateral-wei, scaled by 1e36 (Morpho scale).
///      For BRETT(18)/USDC(6): human_usd * 1e24.
contract MorphoUniV3Oracle {
    IUniswapV3PoolOracle public immutable pool;
    uint32 public immutable twapSeconds;
    bool public immutable collateralIsToken0;
    uint8 public immutable collateralDecimals;
    uint8 public immutable loanDecimals;

    error TwapTooShort();
    error BadTokens();

    constructor(
        address pool_,
        address collateral,
        address loan,
        uint32 twapSeconds_,
        uint8 collateralDecimals_,
        uint8 loanDecimals_
    ) {
        require(twapSeconds_ > 0, "TWAP0");
        pool = IUniswapV3PoolOracle(pool_);
        twapSeconds = twapSeconds_;
        collateralDecimals = collateralDecimals_;
        loanDecimals = loanDecimals_;

        address t0 = IUniswapV3PoolOracle(pool_).token0();
        address t1 = IUniswapV3PoolOracle(pool_).token1();
        bool isToken0;
        if (collateral == t0 && loan == t1) {
            isToken0 = true;
        } else if (collateral == t1 && loan == t0) {
            isToken0 = false;
        } else {
            revert BadTokens();
        }
        collateralIsToken0 = isToken0;
    }

    function price() external view returns (uint256) {
        int24 avgTick = _twapTick();
        uint256 quote = _getQuoteAtTick(avgTick);
        // quote = loan raw units for 1e18 collateral (Uniswap-style FullMath path simplified)
        // Convert to Morpho: loan_amount * 1e36 / collateral_amount with collateral_amount = 1e18 sample.
        // Our _getQuoteAtTick returns loan raw for 10**collateralDecimals collateral units.
        // Morpho wants: price such that (coll * price) / 1e36 = loan_raw
        // For coll = 10**collateralDecimals, loan = quote → price = quote * 1e36 / 10**collateralDecimals
        return (quote * 1e36) / (10 ** uint256(collateralDecimals));
    }

    function _twapTick() internal view returns (int24) {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = twapSeconds;
        secondsAgos[1] = 0;
        (int56[] memory tickCumulatives,) = pool.observe(secondsAgos);
        int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
        int56 twap = int56(uint56(twapSeconds));
        int56 avg = tickCumulativesDelta / twap;
        // round toward negative infinity
        if (tickCumulativesDelta < 0 && (tickCumulativesDelta % twap != 0)) {
            avg -= 1;
        }
        return int24(avg);
    }

    /// @dev Returns loan token raw amount for 10**collateralDecimals units of collateral.
    function _getQuoteAtTick(int24 tick) internal view returns (uint256) {
        uint160 sqrtPriceX96 = _getSqrtRatioAtTick(tick);
        uint256 ratioX192 = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);
        uint256 baseAmount = 10 ** uint256(collateralDecimals);

        if (collateralIsToken0) {
            // amount1 = amount0 * ratio / 2^192
            return FullMath.mulDiv(ratioX192, baseAmount, 1 << 192);
        } else {
            // amount0 = amount1 * 2^192 / ratio
            return FullMath.mulDiv(1 << 192, baseAmount, ratioX192);
        }
    }

    /// @dev Uniswap V3 TickMath.getSqrtRatioAtTick (trimmed).
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

/// @dev Uniswap FullMath.mulDiv
library FullMath {
    function mulDiv(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            uint256 prod0;
            uint256 prod1;
            assembly {
                let mm := mulmod(a, b, not(0))
                prod0 := mul(a, b)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }
            require(denominator > 0);
            if (prod1 == 0) {
                require(denominator > 0);
                assembly {
                    result := div(prod0, denominator)
                }
                return result;
            }
            require(denominator > prod1);
            uint256 remainder;
            assembly {
                remainder := mulmod(a, b, denominator)
            }
            assembly {
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                denominator := div(denominator, twos)
                prod0 := div(prod0, twos)
                twos := add(div(sub(0, twos), twos), 1)
            }
            prod0 |= prod1 * twos;
            uint256 inv = (3 * denominator) ^ 2;
            inv *= 2 - denominator * inv;
            inv *= 2 - denominator * inv;
            inv *= 2 - denominator * inv;
            inv *= 2 - denominator * inv;
            inv *= 2 - denominator * inv;
            inv *= 2 - denominator * inv;
            result = prod0 * inv;
            return result;
        }
    }
}
