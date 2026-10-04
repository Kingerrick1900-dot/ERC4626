// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoRestore {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    function repay(MarketParams memory m, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);

    function withdrawCollateral(MarketParams memory m, uint256 assets, address onBehalf, address receiver) external;

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function accrueInterest(MarketParams memory m) external;

    function isAuthorized(address authorizer, address authorized) external view returns (bool);
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

/// @dev Uni V3 SwapRouter02 exactInputSingle
interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

interface IQuoterV2 {
    struct QuoteExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint24 fee;
        uint160 sqrtPriceLimitX96;
    }

    function quoteExactInputSingle(QuoteExactInputSingleParams memory params)
        external
        returns (uint256 amountOut, uint160, uint32, uint256);
}

/// @title CrownLiquidityRestore
/// @notice DeFi Saver–style close: Morpho flash → repay debt → withdraw eUSD coll →
///         Uni V3 swap eUSD→USDC → repay flash → remainder to HOT.
/// @dev REPAY_SOURCE = UniV3.exactInputSingle(eUSD→USDC). Morpho flash fee = 0.
///      Preflight quotes DEX; reverts Depth if swap cannot cover flash + minToHot.
///      Does NOT mint USDC. Idle self-seed alone cannot net wallet USDC (supply==borrow).
contract CrownLiquidityRestore is Ownable, ReentrancyGuard, IMorphoFlashLoanCallback {
    using SafeTransfer for IERC20;

    IMorphoRestore public immutable morpho;
    ISwapRouter02 public immutable router;
    IQuoterV2 public immutable quoter;
    IERC20 public immutable usdc;
    IERC20 public immutable eusd;
    address public immutable hot;
    bytes32 public immutable marketId;
    IMorphoRestore.MarketParams public mp;
    uint24 public immutable poolFee;

    bool private _locking;
    uint256 private _flashAmt;
    uint256 private _minToHot;
    uint256 private _eusdSellCap;

    event Restored(uint256 flashUsdc, uint256 debtRepaid, uint256 eusdFreed, uint256 usdcFromSwap, uint256 toHot);
    event DepthQuoted(uint256 eusdIn, uint256 usdcOut);

    error OnlyMorpho();
    error Auth();
    error NoPos();
    error Depth();
    error Short();
    error Bad();

    modifier onlyHot() {
        if (msg.sender != owner && msg.sender != hot) revert Auth();
        _;
    }

    constructor(
        address morpho_,
        address router_,
        address quoter_,
        address usdc_,
        address eusd_,
        address hot_,
        address oracle_,
        address irm_,
        uint256 lltv_,
        uint24 poolFee_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoRestore(morpho_);
        router = ISwapRouter02(router_);
        quoter = IQuoterV2(quoter_);
        usdc = IERC20(usdc_);
        eusd = IERC20(eusd_);
        hot = hot_;
        poolFee = poolFee_;
        mp = IMorphoRestore.MarketParams({
            loanToken: usdc_,
            collateralToken: eusd_,
            oracle: oracle_,
            irm: irm_,
            lltv: lltv_
        });
        marketId = keccak256(abi.encode(mp));
    }

    function debtAssets(address user) public view returns (uint256) {
        (, uint128 borShares,) = morpho.position(marketId, user);
        if (borShares == 0) return 0;
        (,, uint128 tba, uint128 tbs,,) = morpho.market(marketId);
        if (tbs == 0) return 0;
        return (uint256(borShares) * uint256(tba) + uint256(tbs) - 1) / uint256(tbs);
    }

    function collateralOf(address user) public view returns (uint256) {
        (,, uint128 coll) = morpho.position(marketId, user);
        return uint256(coll);
    }

    /// @notice View-ish quote via staticcall to QuoterV2 (reverts bubble to caller).
    function quoteEusdToUsdc(uint256 eusdIn) public returns (uint256 usdcOut) {
        if (eusdIn == 0) return 0;
        (usdcOut,,,) = quoter.quoteExactInputSingle(
            IQuoterV2.QuoteExactInputSingleParams({
                tokenIn: address(eusd),
                tokenOut: address(usdc),
                amountIn: eusdIn,
                fee: poolFee,
                sqrtPriceLimitX96: 0
            })
        );
        emit DepthQuoted(eusdIn, usdcOut);
    }

    /// @notice Atomic restore/close. `minToHot` surplus USDC after flash repay (0 allowed).
    /// @param eusdSellCap Max eUSD to sell from freed coll (0 = sell all freed).
    function restore(uint256 minToHot, uint256 eusdSellCap) external onlyHot nonReentrant {
        if (!morpho.isAuthorized(hot, address(this))) revert Auth();

        morpho.accrueInterest(mp);
        (, uint128 borShares, uint128 coll) = morpho.position(marketId, hot);
        if (borShares == 0 || coll == 0) revert NoPos();

        uint256 debt = debtAssets(hot);
        // Tight buffer: $1 on books ≥ $10, else +0.1% (min 1000 raw = $0.001)
        uint256 buf = debt >= 10e6 ? 1e6 : (debt / 1000);
        if (buf < 1000) buf = 1000;
        debt += buf;

        uint256 sell = eusdSellCap == 0 || eusdSellCap > uint256(coll) ? uint256(coll) : eusdSellCap;
        uint256 dexOut = quoteEusdToUsdc(sell);
        if (dexOut < debt + minToHot) revert Depth();

        _flashAmt = debt;
        _minToHot = minToHot;
        _eusdSellCap = sell;
        _locking = true;
        morpho.flashLoan(address(usdc), debt, "");
        _locking = false;
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external override {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        if (!_locking) revert OnlyMorpho();
        if (assets != _flashAmt) revert Bad();

        // 1) Repay Morpho USDC debt
        usdc.safeApprove(address(morpho), assets);
        (, uint128 borShares,) = morpho.position(marketId, hot);
        if (borShares > 0) {
            morpho.repay(mp, 0, borShares, hot, "");
        }

        // 2) Withdraw eUSD collateral to this contract
        (,, uint128 coll) = morpho.position(marketId, hot);
        uint256 freed = uint256(coll);
        if (freed > 0) {
            morpho.withdrawCollateral(mp, freed, hot, address(this));
        }

        // 3) Swap eUSD → USDC on Uni V3 (named repay source)
        uint256 sell = _eusdSellCap < freed ? _eusdSellCap : freed;
        uint256 need = assets + _minToHot;
        uint256 got = 0;
        if (sell > 0) {
            eusd.safeApprove(address(router), sell);
            got = router.exactInputSingle(
                ISwapRouter02.ExactInputSingleParams({
                    tokenIn: address(eusd),
                    tokenOut: address(usdc),
                    fee: poolFee,
                    recipient: address(this),
                    amountIn: sell,
                    amountOutMinimum: need,
                    sqrtPriceLimitX96: 0
                })
            );
            eusd.safeApprove(address(router), 0);
        }
        if (got < need) revert Short();

        // 4) Morpho pulls `assets` after callback (flash fee = 0)
        usdc.safeApprove(address(morpho), assets);

        // 5) Remainder USDC → HOT; leftover eUSD → HOT
        uint256 usdcBal = usdc.balanceOf(address(this));
        if (usdcBal < assets + _minToHot) revert Short();
        uint256 toHot = usdcBal - assets;
        if (toHot > 0) usdc.safeTransfer(hot, toHot);

        uint256 eusdDust = eusd.balanceOf(address(this));
        if (eusdDust > 0) eusd.safeTransfer(hot, eusdDust);

        emit Restored(assets, assets, freed, got, toHot);
    }
}
