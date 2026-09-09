// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoKing {
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

    function repay(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);

    function withdraw(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);

    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data)
        external;

    function borrow(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);

    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function accrueInterest(MarketParams memory marketParams) external;
}

interface IYrssKing {
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

/// @title CrownKingRail
/// @notice Engineered king rail — P1 Landing eUSD pull, P2 eUSD pipe, P3 payroll+cbBTC, P4 lasting USDC idle.
/// @dev Code obeys the king. Same-book gasPark borrow to repay flash = forbidden.
contract CrownKingRail is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IMorphoKing public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable eusd;
    IERC20 public immutable cbbtc;
    IYrssKing public immutable yrss;
    address public immutable king;
    address public landing;

    IMorphoKing.MarketParams public mpEusd;
    IMorphoKing.MarketParams public mpPark;
    IMorphoKing.MarketParams public mpCbbtc;
    bytes32 public eusdMarketId;
    bytes32 public parkMarketId;
    bytes32 public cbbtcMarketId;

    uint256 public minIdleBuffer;
    bool public armed = true;

    uint256 public totalEusdPiped;
    uint256 public totalUsdcLiberated;
    uint256 public totalUsdcIdleEngineered;
    uint256 public lastLiberate;
    uint256 public lastIdle;

    enum FlashOp {
        None,
        LiberatePayroll, // repay park + yRSS→Landing + borrow cbBTC book to repay flash
        AsymIdle // supply park lasting idle + borrow cbBTC book to repay flash
    }

    FlashOp private _op;
    uint256 private _amt;
    uint256 private _coll;

    event LandingSet(address landing);
    event MarketsSet(bytes32 eusdId, bytes32 parkId, bytes32 cbbtcId);
    event Armed(bool on);
    event MinIdleBufferSet(uint256 buffer);
    event EusdPiped(uint256 amt, uint256 idleAfter);
    event PayrollLiberated(uint256 usdcToLanding, uint256 cbbtcColl);
    event AsymIdle(uint256 usdcIdle, uint256 cbbtcColl, uint256 idleAfter);

    error KingOnly();
    error LandingOnly();
    error BadAmt();
    error NotArmed();
    error NoMarket();
    error IdleMiss();
    error WithdrawMiss();
    error LandingMiss();
    error OnlyMorpho();
    error BadOp();
    error NoBorrow();

    modifier onlyKing() {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        _;
    }

    constructor(
        address morpho_,
        address usdc_,
        address eusd_,
        address cbbtc_,
        address yrss_,
        address king_,
        address landing_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoKing(morpho_);
        usdc = IERC20(usdc_);
        eusd = IERC20(eusd_);
        cbbtc = IERC20(cbbtc_);
        yrss = IYrssKing(yrss_);
        king = king_;
        landing = landing_;
        usdc.safeApprove(morpho_, type(uint256).max);
        eusd.safeApprove(morpho_, type(uint256).max);
        cbbtc.safeApprove(morpho_, type(uint256).max);
    }

    function setLanding(address landing_) external onlyOwner {
        if (landing_ == address(0)) revert BadAmt();
        landing = landing_;
        emit LandingSet(landing_);
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
        address oracleEusd,
        address oraclePark,
        address oracleCbbtc,
        address irm,
        uint256 lltvRss,
        uint256 lltvCbbtc,
        bytes32 eusdId,
        bytes32 parkId,
        bytes32 cbbtcId
    ) external onlyOwner {
        mpEusd = IMorphoKing.MarketParams(address(eusd), rss, oracleEusd, irm, lltvRss);
        mpPark = IMorphoKing.MarketParams(address(usdc), rss, oraclePark, irm, lltvRss);
        mpCbbtc = IMorphoKing.MarketParams(address(usdc), address(cbbtc), oracleCbbtc, irm, lltvCbbtc);
        eusdMarketId = eusdId;
        parkMarketId = parkId;
        cbbtcMarketId = cbbtcId;
        emit MarketsSet(eusdId, parkId, cbbtcId);
    }

    function idleEusd() public view returns (uint256) {
        return _idle(eusdMarketId);
    }

    function idlePark() public view returns (uint256) {
        return _idle(parkMarketId);
    }

    function _idle(bytes32 id) internal view returns (uint256) {
        if (id == bytes32(0)) return 0;
        (uint128 s,, uint128 b,,,) = morpho.market(id);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    /// @notice P1 — Landing pulls its Morpho eUSD supply using L0 idle.
    function p1LandingWithdrawEusd(uint256 amt) external nonReentrant returns (uint256 pulled) {
        if (!armed) revert NotArmed();
        if (msg.sender != landing) revert LandingOnly();
        if (eusdMarketId == bytes32(0)) revert NoMarket();
        if (amt == 0) revert BadAmt();
        if (idleEusd() < amt) revert IdleMiss();
        (pulled,) = morpho.withdraw(mpEusd, amt, 0, landing, landing);
        if (pulled < amt) revert WithdrawMiss();
    }

    /// @notice P2 — HOT supply eUSD unmatched then withdraw to Landing.
    function p2PipeEusdToLanding(uint256 amt) external onlyKing nonReentrant returns (uint256 toLanding) {
        if (!armed) revert NotArmed();
        if (eusdMarketId == bytes32(0)) revert NoMarket();
        if (amt == 0) revert BadAmt();
        eusd.safeTransferFrom(msg.sender, address(this), amt);
        uint256 before = idleEusd();
        morpho.supply(mpEusd, amt, 0, address(this), "");
        if (idleEusd() < before + amt - 1) revert IdleMiss();
        (toLanding,) = morpho.withdraw(mpEusd, amt, 0, address(this), landing);
        if (toLanding < amt) revert WithdrawMiss();
        totalEusdPiped += toLanding;
        emit EusdPiped(toLanding, idleEusd());
    }

    /// @notice P3 — Flash USDC, repay park, peel yRSS→Landing, borrow cbBTC/USDC book to repay flash.
    /// @dev Needs cbBTC coll on king + yrss.approve(rail). Lasting park idle ends ~0; Landing gets USDC.
    function p3PayrollWithCbbtc(uint256 usdcAmt, uint256 cbbtcColl) external onlyKing nonReentrant {
        if (!armed) revert NotArmed();
        if (parkMarketId == bytes32(0) || cbbtcMarketId == bytes32(0)) revert NoMarket();
        uint256 claim = yrss.convertToAssets(yrss.balanceOf(king));
        if (usdcAmt == 0 || usdcAmt > claim) usdcAmt = claim;
        if (usdcAmt == 0 || cbbtcColl == 0) revert BadAmt();
        cbbtc.safeTransferFrom(msg.sender, address(this), cbbtcColl);
        _op = FlashOp.LiberatePayroll;
        _amt = usdcAmt;
        _coll = cbbtcColl;
        morpho.flashLoan(address(usdc), usdcAmt, "");
        _op = FlashOp.None;
    }

    /// @notice P4 — Flash USDC, supply park lasting idle, borrow cbBTC book to repay. Idle STAYS.
    function p4AsymIdle(uint256 usdcIdle, uint256 cbbtcColl) external onlyKing nonReentrant returns (uint256 idleAfter) {
        if (!armed) revert NotArmed();
        if (parkMarketId == bytes32(0) || cbbtcMarketId == bytes32(0)) revert NoMarket();
        if (usdcIdle == 0 || cbbtcColl == 0) revert BadAmt();
        cbbtc.safeTransferFrom(msg.sender, address(this), cbbtcColl);
        _op = FlashOp.AsymIdle;
        _amt = usdcIdle;
        _coll = cbbtcColl;
        morpho.flashLoan(address(usdc), usdcIdle, "");
        _op = FlashOp.None;
        idleAfter = idlePark();
        if (idleAfter < minIdleBuffer) revert IdleMiss();
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external {
        if (msg.sender != address(morpho)) revert OnlyMorpho();
        FlashOp op = _op;
        uint256 amt = _amt;
        uint256 coll = _coll;
        if (assets < amt) revert BadAmt();

        if (op == FlashOp.LiberatePayroll) {
            morpho.accrueInterest(mpPark);
            morpho.repay(mpPark, amt, 0, king, "");
            if (idlePark() == 0) revert IdleMiss();
            uint256 maxW = yrss.maxWithdraw(king);
            if (maxW < amt) amt = maxW;
            if (amt == 0) revert WithdrawMiss();
            uint256 before = usdc.balanceOf(landing);
            uint256 got = yrss.withdraw(amt, landing, king);
            if (got < amt || usdc.balanceOf(landing) < before + amt) revert LandingMiss();
            totalUsdcLiberated += amt;
            lastLiberate = amt;
            emit PayrollLiberated(amt, coll);
            // Repay flash from cbBTC/USDC deep book — NOT park
            morpho.supplyCollateral(mpCbbtc, coll, address(this), "");
            morpho.borrow(mpCbbtc, assets, 0, address(this), address(this));
            return;
        }

        if (op == FlashOp.AsymIdle) {
            morpho.supply(mpPark, amt, 0, address(this), "");
            uint256 idleAfter = idlePark();
            if (idleAfter < amt - 1) revert IdleMiss();
            if (minIdleBuffer < amt) {
                minIdleBuffer = amt;
                emit MinIdleBufferSet(minIdleBuffer);
            }
            morpho.supplyCollateral(mpCbbtc, coll, address(this), "");
            morpho.borrow(mpCbbtc, assets, 0, address(this), address(this));
            totalUsdcIdleEngineered += amt;
            lastIdle = amt;
            emit AsymIdle(amt, coll, idlePark());
            return;
        }

        revert BadOp();
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
