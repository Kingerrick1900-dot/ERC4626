// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoDex {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    function repay(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes memory data
    ) external returns (uint256, uint256);

    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver)
        external;

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function accrueInterest(MarketParams memory marketParams) external;

    function isAuthorized(address authorizer, address authorized) external view returns (bool);
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

interface IAeroRouter {
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    function getAmountsOut(uint256 amountIn, Route[] calldata routes) external view returns (uint256[] memory amounts);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

interface IAeroPair {
    function getReserves() external view returns (uint112, uint112, uint32);
    function token0() external view returns (address);
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);
}

/// @notice Pure Flash-Unwind / Atomic DEX Flash Router — liquid USDC from Base DEX in one block.
/// @dev Does NOT query Morpho borrow idle / PA maxIn. Extracts via Aerodrome RSS→USDC.
///      Modes:
///        1) extractUsdc — pull free RSS → DEX swap → Landing
///        2) flashUnwindExtract — Morpho flash repay debt → free coll → DEX sell to repay flash
///           → leftover USDC to Landing (requires DEX depth ≥ flash)
///      Elepan never touched.
contract CrownAtomicDexFlashRouter is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    IMorphoDex public immutable morpho;
    IAeroRouter public immutable aeroRouter;
    IAeroPair public immutable aeroPair;
    IERC20 public immutable usdc;
    IERC20 public immutable rss;
    address public immutable aeroFactory;
    address public immutable king; // hot
    address public immutable landing;
    bytes32 public immutable marketId;
    IMorphoDex.MarketParams public mp;

    // Elepan denylist — hardcoded, never approve/transfer
    address public constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;

    bool private _flashActive;
    uint256 private _flashAmt;
    uint256 private _minUsdcToLanding;
    uint256 private _rssSellCap;

    event DexExtract(uint256 rssIn, uint256 usdcOut, address indexed to);
    event FlashUnwind(uint256 flashUsdc, uint256 debtRepaid, uint256 rssFreed, uint256 usdcToLanding, uint256 rssDust);

    error OnlyMorpho();
    error NotKing();
    error Zero();
    error Depth();
    error Slippage();
    error Elepan();
    error Auth();

    constructor(
        address morpho_,
        address usdc_,
        address rss_,
        address aeroRouter_,
        address aeroPair_,
        address aeroFactory_,
        address king_,
        address landing_,
        bytes32 marketId_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        address owner_
    ) Ownable(owner_) {
        require(
            morpho_ != address(0) && usdc_ != address(0) && rss_ != address(0) && aeroRouter_ != address(0)
                && aeroPair_ != address(0) && king_ != address(0) && landing_ != address(0),
            "ZERO"
        );
        morpho = IMorphoDex(morpho_);
        usdc = IERC20(usdc_);
        rss = IERC20(rss_);
        aeroRouter = IAeroRouter(aeroRouter_);
        aeroPair = IAeroPair(aeroPair_);
        aeroFactory = aeroFactory_;
        king = king_;
        landing = landing_;
        marketId = marketId_;
        mp = IMorphoDex.MarketParams({
            loanToken: usdc_,
            collateralToken: rss_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
    }

    /*////////// QUOTES (DEX only — no Morpho borrow queue) //////////*/

    /// @notice USDC reserve in the Aerodrome RSS/USDC pool (extractable ceiling ≈ this).
    function dexUsdcReserve() public view returns (uint256) {
        return usdc.balanceOf(address(aeroPair));
    }

    /// @notice Quote RSS→USDC via Aerodrome (view).
    function quoteUsdcOut(uint256 rssIn) public view returns (uint256) {
        if (rssIn == 0) return 0;
        IAeroRouter.Route[] memory routes = _routes();
        uint256[] memory amounts = aeroRouter.getAmountsOut(rssIn, routes);
        return amounts[amounts.length - 1];
    }

    /// @notice Max RSS to sell while keeping `maxBps` of pool USDC reserve (default 5000 = 50%).
    function maxRssForDepth(uint256 maxBps) external view returns (uint256 rssIn, uint256 usdcOut) {
        uint256 reserve = dexUsdcReserve();
        if (reserve == 0) return (0, 0);
        uint256 target = (reserve * maxBps) / 10_000;
        // binary search rss in for ~target USDC out
        uint256 lo = 1;
        uint256 hi = 1_000_000 ether; // 1M RSS search cap
        while (lo < hi) {
            uint256 mid = (lo + hi + 1) / 2;
            uint256 out = aeroPair.getAmountOut(mid, address(rss));
            if (out <= target) lo = mid;
            else hi = mid - 1;
        }
        rssIn = lo;
        usdcOut = quoteUsdcOut(rssIn);
    }

    /*////////// MODE 1: direct DEX extract (free RSS → Landing USDC) //////////*/

    /// @notice Pull `rssIn` from king, swap on Aerodrome, send USDC to Landing. One tx.
    function extractUsdc(uint256 rssIn, uint256 minUsdcOut) external nonReentrant {
        if (msg.sender != king && msg.sender != owner) revert NotKing();
        if (rssIn == 0) revert Zero();
        if (address(rss) == ELEPAN) revert Elepan();

        uint256 quoted = quoteUsdcOut(rssIn);
        if (quoted < minUsdcOut) revert Slippage();
        // Hard depth gate: never try to take more USDC than sits in the pool
        if (minUsdcOut > dexUsdcReserve()) revert Depth();

        rss.safeTransferFrom(king, address(this), rssIn);
        uint256 usdcOut = _swapRssForUsdc(rssIn, minUsdcOut, landing);
        emit DexExtract(rssIn, usdcOut, landing);
    }

    /*////////// MODE 2: Morpho flash-unwind → DEX repay → Landing leftover //////////*/

    /// @notice Flash USDC → repay king's Morpho debt → withdraw RSS → sell RSS on DEX to repay flash
    ///         → leftover USDC to Landing. Reverts if DEX depth cannot cover flash (honest).
    /// @param minUsdcToLanding Surplus USDC that must remain after flash repay (can be 0).
    /// @param rssSellCap Max RSS to sell from freed collateral (rest returned to king).
    function flashUnwindExtract(uint256 minUsdcToLanding, uint256 rssSellCap) external nonReentrant {
        if (msg.sender != king && msg.sender != owner) revert NotKing();
        if (!morpho.isAuthorized(king, address(this))) revert Auth();

        morpho.accrueInterest(mp);
        (, uint128 borShares, uint128 coll) = morpho.position(marketId, king);
        require(borShares > 0 && coll > 0, "NO_POS");

        (,, uint128 tba, uint128 tbs,,) = morpho.market(marketId);
        uint256 debt = (uint256(tba) * uint256(borShares) + uint256(tbs) - 1) / uint256(tbs);
        debt += 1e6; // $1 buffer

        // Preflight: DEX must be able to return ≥ debt from rssSellCap (else don't start flash)
        uint256 sell = rssSellCap == 0 || rssSellCap > uint256(coll) ? uint256(coll) : rssSellCap;
        uint256 dexOut = quoteUsdcOut(sell);
        if (dexOut < debt + minUsdcToLanding) revert Depth();

        _flashActive = true;
        _flashAmt = debt;
        _minUsdcToLanding = minUsdcToLanding;
        _rssSellCap = sell;
        morpho.flashLoan(address(usdc), debt, bytes(""));
        _flashActive = false;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external override {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        if (!_flashActive) revert OnlyMorpho();
        require(assets == _flashAmt, "FLASH_AMT");

        // 1) Repay debt
        usdc.safeApprove(address(morpho), assets);
        morpho.repay(mp, assets, 0, king, bytes(""));

        // 2) Withdraw all RSS collateral to this router
        (, , uint128 coll) = morpho.position(marketId, king);
        uint256 freed = uint256(coll);
        if (freed > 0) {
            morpho.withdrawCollateral(mp, freed, king, address(this));
        }

        // 3) Sell RSS on Aerodrome → USDC to this router (enough to repay flash + optional landing min)
        uint256 sell = _rssSellCap < freed ? _rssSellCap : freed;
        uint256 need = assets + _minUsdcToLanding;
        uint256 got = _swapRssForUsdc(sell, need, address(this));

        // 4) Approve Morpho to pull flash repay (0% fee)
        usdc.safeApprove(address(morpho), assets);

        // 5) Leftover USDC → Landing; leftover RSS → king
        uint256 usdcBal = usdc.balanceOf(address(this));
        // Morpho will pull `assets` after callback returns; reserve it
        require(usdcBal >= assets + _minUsdcToLanding, "LANDING_MIN");
        uint256 toLanding = usdcBal - assets;
        if (toLanding > 0) {
            usdc.safeTransfer(landing, toLanding);
        }
        uint256 rssDust = rss.balanceOf(address(this));
        if (rssDust > 0) {
            rss.safeTransfer(king, rssDust);
        }

        emit FlashUnwind(assets, assets, freed, toLanding, rssDust);
        // silence unused
        got;
    }

    /*////////// INTERNAL //////////*/

    function _routes() internal view returns (IAeroRouter.Route[] memory routes) {
        routes = new IAeroRouter.Route[](1);
        routes[0] = IAeroRouter.Route({from: address(rss), to: address(usdc), stable: false, factory: aeroFactory});
    }

    function _swapRssForUsdc(uint256 rssIn, uint256 minOut, address to) internal returns (uint256 usdcOut) {
        if (rssIn == 0) revert Zero();
        rss.safeApprove(address(aeroRouter), rssIn);
        uint256[] memory amounts = aeroRouter.swapExactTokensForTokens(
            rssIn, minOut, _routes(), to, block.timestamp + 15 minutes
        );
        usdcOut = amounts[amounts.length - 1];
        if (usdcOut < minOut) revert Slippage();
        rss.safeApprove(address(aeroRouter), 0);
    }
}
