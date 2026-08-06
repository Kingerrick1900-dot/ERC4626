// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CrownAeroPool1MSeed
/// @notice Make Aero RSS/USDC `0x2C4F…537a` LOOK like ≥ $1M USDC depth.
/// King knows live depth is ~$0.67 — engineer the optics.
///
/// ### Why not Router addLiquidity
/// Pool ratio ≈ 149_850 RSS : $0.67 USDC. UniV2-style `mint` takes min(side0, side1) —
/// USDC-only add mints **0 LP** (LOOK / Insufficient Liquidity Burned).
///
/// ### Engineer
/// **Ephemeral LOOK:** Morpho flash USDC → `transfer(pool)` + `sync()` → peak reserves ≥ $1M
/// → sell free RSS into stuffed pool → reclaim USDC → repay flash. Dust → Landing.
/// **Persist LOOK:** real USDC left in the pool via donate+`sync()` (costs the USDC).

interface IERC20A {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IMorphoA {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface IAeroPair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
    function sync() external;
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

contract CrownAeroPool1MSeed {
    uint256 internal constant LOOK_USDC = 1_000_000e6;

    IMorphoA public immutable morpho;
    IERC20A public immutable usdc;
    IERC20A public immutable rss;
    IAeroPair public immutable pool;
    address public immutable king;
    address public immutable landing;
    bool public immutable rssIsToken0;

    uint256 public lastPoolUsdcPeak;
    uint256 public lastResidualUsdc;
    uint256 public lastRssSpent;
    bool public fired;

    error KingOnly();
    error AlreadyFired();
    error LookMiss();
    error RepayFail();
    error NoRss();

    constructor(
        address morpho_,
        address usdc_,
        address rss_,
        address pool_,
        address king_,
        address landing_
    ) {
        morpho = IMorphoA(morpho_);
        usdc = IERC20A(usdc_);
        rss = IERC20A(rss_);
        pool = IAeroPair(pool_);
        king = king_;
        landing = landing_;
        rssIsToken0 = IAeroPair(pool_).token0() == rss_;
    }

    /// @notice Flash ≥ $1M USDC, inflate pool LOOK, reclaim with RSS, repay.
    /// @dev Constant-product + Aero fee ⇒ reclaim from a stuffed pool is always &lt; donate.
    ///      `usdcBuffer` (pull from King) covers that gap (~2–3% of LOOK). Without it, repay reverts.
    /// @param usdcFlash USDC to flash (must be ≥ LOOK_USDC) — all donated into pool for LOOK
    /// @param rssMax    Free RSS pulled from King for reclaim swap
    /// @param usdcBuffer USDC from King to cover fee/CP gap so Morpho repay clears
    function lookEphemeral(uint256 usdcFlash, uint256 rssMax, uint256 usdcBuffer) external {
        if (msg.sender != king) revert KingOnly();
        if (fired) revert AlreadyFired();
        if (usdcFlash < LOOK_USDC) revert LookMiss();
        fired = true;

        if (rssMax > 0) {
            require(rss.transferFrom(king, address(this), rssMax), "RSS");
        }
        if (usdcBuffer > 0) {
            require(usdc.transferFrom(king, address(this), usdcBuffer), "BUF");
        }
        morpho.flashLoan(address(usdc), usdcFlash, abi.encode(uint8(0), usdcFlash));
    }

    /// @notice Leave real USDC in the pool so LOOK persists (costs `usdcAmt`). Pulls from King.
    function lookPersist(uint256 usdcAmt) external {
        if (msg.sender != king) revert KingOnly();
        if (fired) revert AlreadyFired();
        if (usdcAmt < LOOK_USDC) revert LookMiss();
        fired = true;

        require(usdc.transferFrom(king, address(this), usdcAmt), "USDC");
        _donateSync(usdcAmt);
        if (lastPoolUsdcPeak < LOOK_USDC) revert LookMiss();
    }

    /// @notice Persist LOOK funded on chassis (e.g. fork `deal`) — flash inflate, repay from prefund, LP stays stuffed.
    function lookPersistFlash(uint256 usdcFlash) external {
        if (msg.sender != king) revert KingOnly();
        if (fired) revert AlreadyFired();
        if (usdcFlash < LOOK_USDC) revert LookMiss();
        // Prefund must cover flash repay (Morpho flash is free; need ≥ usdcFlash sitting here).
        if (usdc.balanceOf(address(this)) < usdcFlash) revert RepayFail();
        fired = true;
        morpho.flashLoan(address(usdc), usdcFlash, abi.encode(uint8(1), usdcFlash));
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external {
        require(msg.sender == address(morpho), "MORPHO");
        (uint8 mode, uint256 usdcFlash) = abi.decode(data, (uint8, uint256));
        require(assets == usdcFlash, "AMT");

        if (mode == 1) {
            // Persist: donate flashed USDC; repay from prefund left on chassis.
            _donateSync(usdcFlash);
            if (lastPoolUsdcPeak < LOOK_USDC) revert LookMiss();
            usdc.approve(address(morpho), usdcFlash);
            return;
        }

        // Ephemeral: donate full flash for LOOK → reclaim with RSS → buffer + reclaim repay Morpho
        _donateSync(usdcFlash);
        if (lastPoolUsdcPeak < LOOK_USDC) revert LookMiss();

        uint256 stillNeed = usdcFlash > usdc.balanceOf(address(this))
            ? usdcFlash - usdc.balanceOf(address(this))
            : 0;
        if (stillNeed > 0) {
            _reclaimUsdc(stillNeed);
        }

        uint256 bal = usdc.balanceOf(address(this));
        if (bal < usdcFlash) revert RepayFail();

        uint256 dust = bal - usdcFlash;
        if (dust > 0 && landing != address(0)) {
            usdc.transfer(landing, dust);
            lastResidualUsdc = dust;
        }
        usdc.approve(address(morpho), usdcFlash);
    }

    function _donateSync(uint256 usdcAmt) internal {
        usdc.transfer(address(pool), usdcAmt);
        pool.sync();
        (uint112 r0, uint112 r1,) = pool.getReserves();
        lastPoolUsdcPeak = rssIsToken0 ? uint256(r1) : uint256(r0);
    }

    /// @dev Sell RSS into stuffed pool for USDC. Targets enough to repay flash.
    function _reclaimUsdc(uint256 needUsdc) internal {
        uint256 rssBal = rss.balanceOf(address(this));
        if (rssBal == 0) revert NoRss();

        (uint112 r0, uint112 r1,) = pool.getReserves();
        uint256 rRss = rssIsToken0 ? uint256(r0) : uint256(r1);
        uint256 rUsdc = rssIsToken0 ? uint256(r1) : uint256(r0);

        // Pull as much as needed for repay, capped by inventory / 99% of reserve.
        uint256 want = needUsdc;
        if (want > (rUsdc * 99) / 100) want = (rUsdc * 99) / 100;

        // UniV2 amountIn for amountOut (volatile): x = rIn * out / (rOut - out), then +0.3% fee.
        uint256 needRss = (rRss * want) / (rUsdc - want) + 1;
        needRss = (needRss * 1000) / 997 + 1;

        if (needRss > rssBal) {
            needRss = rssBal;
            // max out ≈ rUsdc * in / (rRss + in), haircut fee
            want = (rUsdc * needRss) / (rRss + needRss);
            want = (want * 997) / 1000;
        }

        if (want == 0 || needRss == 0) revert RepayFail();

        rss.transfer(address(pool), needRss);
        lastRssSpent = needRss;

        if (rssIsToken0) {
            pool.swap(0, want, address(this), "");
        } else {
            pool.swap(want, 0, address(this), "");
        }
    }
}
