// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoCb {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external;

    function supply(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);

    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data)
        external;

    function borrow(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);

    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface IOracleCb {
    function price() external view returns (uint256);
}

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

/// @title CrownCbbtcIdlePuller
/// @notice Engineer LASTING park USDC idle from cbBTC — pull millions at will when coll is funded.
/// @dev Asymmetric L2: flash USDC → supply park (idle STAYS) → coll+borrow cbBTC/USDC deep book → repay flash.
///      Same-book gasPark forbidden. Dust ladder: Unlatch $1.51 → FakeIdle eUSD → Ocean 5B → THIS.
contract CrownCbbtcIdlePuller is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint256 public constant ORACLE_SCALE = 1e36;
    uint256 public constant WAD = 1e18;
    uint256 public constant DEFAULT_ASK = 1_500_000e6;
    uint256 public constant HAIRCUT_BPS = 9_500; // use 95% of LLTV capacity
    uint256 public constant BPS = 10_000;

    IMorphoCb public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable cbbtc;
    address public immutable king;
    ISwapRouter02 public immutable router;
    uint24 public immutable uniFee;

    IMorphoCb.MarketParams public mpPark;
    IMorphoCb.MarketParams public mpCbbtc;
    bytes32 public parkMarketId;
    bytes32 public cbbtcMarketId;
    address public oracleCbbtc;

    uint256 public minIdleBuffer;
    bool public armed = true;

    uint256 public totalIdlePulled;
    uint256 public totalCbbtcPosted;
    uint256 public lastPull;
    uint256 public lastColl;

    bool private _flashing;
    uint256 private _pullAmt;
    uint256 private _collAmt;

    event MarketsSet(bytes32 parkId, bytes32 cbbtcId, address oracle);
    event Armed(bool on);
    event MinIdleBufferSet(uint256 buffer);
    event IdlePulled(uint256 usdcIdle, uint256 cbbtcColl, uint256 idleAfter);
    event BoughtCbbtc(uint256 usdcIn, uint256 cbbtcOut);

    error KingOnly();
    error BadAmt();
    error NotArmed();
    error NoMarket();
    error IdleMiss();
    error OnlyMorpho();
    error CollMiss();
    error BookMiss();
    error NoBorrow();
    error SwapMiss();

    modifier onlyKing() {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        _;
    }

    constructor(
        address morpho_,
        address usdc_,
        address cbbtc_,
        address king_,
        address router_,
        uint24 uniFee_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoCb(morpho_);
        usdc = IERC20(usdc_);
        cbbtc = IERC20(cbbtc_);
        king = king_;
        router = ISwapRouter02(router_);
        uniFee = uniFee_;
        usdc.safeApprove(morpho_, type(uint256).max);
        cbbtc.safeApprove(morpho_, type(uint256).max);
        if (router_ != address(0)) {
            usdc.safeApprove(router_, type(uint256).max);
        }
    }

    function setArmed(bool on) external onlyOwner {
        armed = on;
        emit Armed(on);
    }

    function setMinIdleBuffer(uint256 buffer) external onlyOwner {
        minIdleBuffer = buffer;
        emit MinIdleBufferSet(buffer);
    }

    function setMarkets(
        address rss,
        address oraclePark,
        address oracleCbbtc_,
        address irm,
        uint256 lltvPark,
        uint256 lltvCbbtc,
        bytes32 parkId,
        bytes32 cbbtcId
    ) external onlyOwner {
        if (oracleCbbtc_ == address(0) || parkId == bytes32(0) || cbbtcId == bytes32(0)) revert BadAmt();
        mpPark = IMorphoCb.MarketParams(address(usdc), rss, oraclePark, irm, lltvPark);
        mpCbbtc = IMorphoCb.MarketParams(address(usdc), address(cbbtc), oracleCbbtc_, irm, lltvCbbtc);
        parkMarketId = parkId;
        cbbtcMarketId = cbbtcId;
        oracleCbbtc = oracleCbbtc_;
        emit MarketsSet(parkId, cbbtcId, oracleCbbtc_);
    }

    function idlePark() public view returns (uint256) {
        return _idle(parkMarketId);
    }

    function idleCbbtcBook() public view returns (uint256) {
        return _idle(cbbtcMarketId);
    }

    function _idle(bytes32 id) internal view returns (uint256) {
        if (id == bytes32(0)) return 0;
        (uint128 s,, uint128 b,,,) = morpho.market(id);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    /// @notice USD value of cbBTC coll in USDC base units (6dp) via Morpho oracle.
    function collValueUsdc(uint256 cbbtcAmt) public view returns (uint256) {
        if (oracleCbbtc == address(0) || cbbtcAmt == 0) return 0;
        return cbbtcAmt * IOracleCb(oracleCbbtc).price() / ORACLE_SCALE;
    }

    /// @notice Max USDC borrow/idle from coll at haircut LLTV.
    function quoteMaxIdle(uint256 cbbtcAmt) public view returns (uint256) {
        if (mpCbbtc.lltv == 0) return 0;
        uint256 value = collValueUsdc(cbbtcAmt);
        uint256 atLltv = value * mpCbbtc.lltv / WAD;
        return atLltv * HAIRCUT_BPS / BPS;
    }

    /// @notice cbBTC wei needed for target lasting USDC idle (haircut LLTV).
    function quoteCollForIdle(uint256 usdcIdle) public view returns (uint256) {
        if (usdcIdle == 0 || oracleCbbtc == address(0) || mpCbbtc.lltv == 0) return 0;
        uint256 price = IOracleCb(oracleCbbtc).price();
        if (price == 0) return 0;
        // usdc <= coll * price / 1e36 * lltv / 1e18 * haircut/bps
        // coll >= usdc * 1e36 * 1e18 * bps / (price * lltv * haircut)
        uint256 num = usdcIdle * ORACLE_SCALE * WAD * BPS;
        uint256 den = price * mpCbbtc.lltv * HAIRCUT_BPS;
        return (num + den - 1) / den;
    }

    /// @notice Kingdom wealth board — idle books + sizing for ASK.
    function wealthBoard()
        external
        view
        returns (
            uint256 parkIdle,
            uint256 cbbtcBookIdle,
            uint256 ask,
            uint256 collForAsk,
            uint256 kingCbbtc,
            uint256 maxPullNow
        )
    {
        parkIdle = idlePark();
        cbbtcBookIdle = idleCbbtcBook();
        ask = DEFAULT_ASK;
        collForAsk = quoteCollForIdle(ask);
        kingCbbtc = cbbtc.balanceOf(king);
        maxPullNow = quoteMaxIdle(kingCbbtc);
    }

    /// @notice Pull lasting park USDC idle sized from king cbBTC (or explicit coll).
    /// @param usdcIdle Target unmatched idle to leave on park (0 = max from coll).
    /// @param cbbtcColl Coll to post (0 = auto quoteCollForIdle(usdcIdle) or all king bal for max).
    function pullIdle(uint256 usdcIdle, uint256 cbbtcColl) external onlyKing nonReentrant returns (uint256 idleAfter) {
        idleAfter = _pullFromKing(msg.sender, usdcIdle, cbbtcColl);
    }

    /// @notice Convenience — pull DEFAULT_ASK ($1.5M) lasting idle.
    function pullMillions() external onlyKing nonReentrant returns (uint256 idleAfter) {
        idleAfter = _pullFromKing(msg.sender, DEFAULT_ASK, 0);
    }

    function _pullFromKing(address from, uint256 usdcIdle, uint256 cbbtcColl) internal returns (uint256 idleAfter) {
        if (!armed) revert NotArmed();
        if (parkMarketId == bytes32(0) || cbbtcMarketId == bytes32(0)) revert NoMarket();

        if (cbbtcColl == 0 && usdcIdle == 0) {
            cbbtcColl = cbbtc.balanceOf(from);
            usdcIdle = quoteMaxIdle(cbbtcColl);
        } else if (cbbtcColl == 0) {
            cbbtcColl = quoteCollForIdle(usdcIdle);
        } else if (usdcIdle == 0) {
            usdcIdle = quoteMaxIdle(cbbtcColl);
        }

        if (usdcIdle == 0 || cbbtcColl == 0) revert BadAmt();
        if (idleCbbtcBook() < usdcIdle) revert BookMiss();
        if (quoteMaxIdle(cbbtcColl) < usdcIdle) revert CollMiss();

        cbbtc.safeTransferFrom(from, address(this), cbbtcColl);
        _flashAndEngineer(usdcIdle, cbbtcColl);
        idleAfter = idlePark();
        if (minIdleBuffer > 0 && idleAfter < minIdleBuffer) revert IdleMiss();
    }

    function _flashAndEngineer(uint256 usdcIdle, uint256 cbbtcColl) internal {
        _flashing = true;
        _pullAmt = usdcIdle;
        _collAmt = cbbtcColl;
        morpho.flashLoan(address(usdc), usdcIdle, "");
        _flashing = false;
    }

    /// @notice When USDC lands on king: buy cbBTC on Uni then pull lasting idle (optics/path demo).
    /// @dev Direct USDC→park supply is more efficient; this path exists for cbBTC-rail continuity.
    function buyCbbtcAndPull(uint256 usdcIn, uint256 minCbbtcOut, uint256 usdcIdle)
        external
        onlyKing
        nonReentrant
        returns (uint256 idleAfter, uint256 cbbtcOut)
    {
        if (!armed) revert NotArmed();
        if (address(router) == address(0)) revert SwapMiss();
        if (usdcIn == 0) revert BadAmt();
        usdc.safeTransferFrom(msg.sender, address(this), usdcIn);
        cbbtcOut = router.exactInputSingle(
            ISwapRouter02.ExactInputSingleParams({
                tokenIn: address(usdc),
                tokenOut: address(cbbtc),
                fee: uniFee,
                recipient: address(this),
                amountIn: usdcIn,
                amountOutMinimum: minCbbtcOut,
                sqrtPriceLimitX96: 0
            })
        );
        if (cbbtcOut < minCbbtcOut || cbbtcOut == 0) revert SwapMiss();
        emit BoughtCbbtc(usdcIn, cbbtcOut);

        if (usdcIdle == 0) usdcIdle = quoteMaxIdle(cbbtcOut);
        if (usdcIdle == 0) revert BadAmt();
        if (quoteMaxIdle(cbbtcOut) < usdcIdle) usdcIdle = quoteMaxIdle(cbbtcOut);
        if (idleCbbtcBook() < usdcIdle) revert BookMiss();

        _flashAndEngineer(usdcIdle, cbbtcOut);
        idleAfter = idlePark();
        if (minIdleBuffer > 0 && idleAfter < minIdleBuffer) revert IdleMiss();
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        if (!_flashing) revert BadAmt();
        uint256 amt = _pullAmt;
        uint256 coll = _collAmt;
        if (assets < amt) revert BadAmt();

        morpho.supply(mpPark, amt, 0, address(this), "");
        if (idlePark() < amt - 1) revert IdleMiss();

        if (minIdleBuffer < amt) {
            minIdleBuffer = amt;
            emit MinIdleBufferSet(minIdleBuffer);
        }

        morpho.supplyCollateral(mpCbbtc, coll, address(this), "");
        morpho.borrow(mpCbbtc, assets, 0, address(this), address(this));

        totalIdlePulled += amt;
        totalCbbtcPosted += coll;
        lastPull = amt;
        lastColl = coll;
        emit IdlePulled(amt, coll, idlePark());
    }

    function borrow(uint256) external pure {
        revert NoBorrow();
    }

    function gasPark(uint256, uint256) external pure {
        revert NoBorrow();
    }

    function sweep(address token, uint256 amt) external onlyOwner {
        IERC20(token).safeTransfer(king, amt == 0 ? IERC20(token).balanceOf(address(this)) : amt);
    }
}
