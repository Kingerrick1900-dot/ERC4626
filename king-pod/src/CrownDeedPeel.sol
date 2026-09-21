// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoDeed {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function repay(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);

    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);

    function accrueInterest(MarketParams memory marketParams) external;
}

interface IYrssDeed {
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

/// @title CrownDeedPeel
/// @notice Easy path: open park util (repay-for king) → peel yRSS deed → Landing.
/// @dev Proved peel already works when idle > 0. This unmatches the deed then peels.
///      No gasPark. No borrow. No eUSD→USDC fantasy.
contract CrownDeedPeel is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IMorphoDeed public immutable morpho;
    IERC20 public immutable usdc;
    IYrssDeed public immutable yrss;
    address public immutable king;
    address public landing;

    IMorphoDeed.MarketParams public mp;
    bytes32 public marketId;
    bool public armed = true;

    uint256 public totalRepaid;
    uint256 public totalPeeled;
    uint256 public lastRepay;
    uint256 public lastPeel;

    event LandingSet(address landing);
    event MarketSet(bytes32 indexed id);
    event Armed(bool on);
    event DeedUnmatched(uint256 repaid, uint256 idleAfter, uint256 utilBps);
    event DeedPeeled(uint256 peeled, uint256 landingBal, uint256 idleLeft);

    error KingOnly();
    error BadAmt();
    error NotArmed();
    error NoMarket();
    error IdleMiss();
    error WithdrawMiss();
    error LandingMiss();
    error NoDebt();
    error NoBorrow();
    error NeedApprove();

    modifier onlyKing() {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        _;
    }

    constructor(
        address morpho_,
        address usdc_,
        address yrss_,
        address king_,
        address landing_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoDeed(morpho_);
        usdc = IERC20(usdc_);
        yrss = IYrssDeed(yrss_);
        king = king_;
        landing = landing_;
        usdc.safeApprove(morpho_, type(uint256).max);
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

    function setMarket(address rss, address oracle, address irm, uint256 lltv, bytes32 id) external onlyOwner {
        if (rss == address(0) || oracle == address(0) || irm == address(0) || id == bytes32(0)) revert BadAmt();
        mp = IMorphoDeed.MarketParams(address(usdc), rss, oracle, irm, lltv);
        marketId = id;
        emit MarketSet(id);
    }

    function idle() public view returns (uint256) {
        if (marketId == bytes32(0)) return 0;
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    function utilBps() public view returns (uint256) {
        if (marketId == bytes32(0)) return 0;
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        if (s == 0) return 0;
        return (uint256(b) * 10_000) / uint256(s);
    }

    function deedAssets() public view returns (uint256) {
        return yrss.convertToAssets(yrss.balanceOf(king));
    }

    function maxPeel() public view returns (uint256) {
        return yrss.maxWithdraw(king);
    }

    function kingBorrowAssets() public view returns (uint256) {
        if (marketId == bytes32(0)) return 0;
        (, uint128 borShares,) = morpho.position(marketId, king);
        if (borShares == 0) return 0;
        (,, uint128 tba, uint128 tbs,,) = morpho.market(marketId);
        if (tbs == 0) return 0;
        return (uint256(tba) * uint256(borShares) + uint256(tbs) - 1) / uint256(tbs);
    }

    /// @notice Scoreboard — deed, peelable now, debt to cut, util.
    function board()
        external
        view
        returns (
            uint256 deed,
            uint256 peelable,
            uint256 parkIdle,
            uint256 kingDebt,
            uint256 util,
            uint256 yrssAllowance
        )
    {
        deed = deedAssets();
        peelable = maxPeel();
        parkIdle = idle();
        kingDebt = kingBorrowAssets();
        util = utilBps();
        yrssAllowance = yrss.allowance(king, address(this));
    }

    /// @notice Peel whatever idle already allows (proved dust path).
    function peelDust() external onlyKing nonReentrant returns (uint256 peeled) {
        if (!armed) revert NotArmed();
        peeled = _peel(0);
    }

    /// @notice Robot: peel when idle opens.
    function pokePeel() external nonReentrant returns (uint256 peeled) {
        if (!armed) revert NotArmed();
        if (idle() == 0 || maxPeel() == 0) revert IdleMiss();
        peeled = _peel(0);
    }

    /// @notice Cut king park debt with USDC → util drops → idle opens.
    function unmatch(uint256 repayAmt) external onlyKing nonReentrant returns (uint256 idleAfter) {
        idleAfter = _unmatch(repayAmt);
    }

    /// @notice Easy path one tx: repay-for king → peel deed → Landing.
    /// @param repayAmt USDC to repay (0 = min(debt, bal+pull from king) capped to deed).
    /// @param peelAmt yRSS assets to Landing (0 = maxWithdraw after unmatch).
    function unmatchAndPeel(uint256 repayAmt, uint256 peelAmt)
        external
        onlyKing
        nonReentrant
        returns (uint256 idleAfter, uint256 peeled)
    {
        if (!armed) revert NotArmed();
        idleAfter = _unmatch(repayAmt);
        peeled = _peel(peelAmt);
    }

    function _unmatch(uint256 repayAmt) internal returns (uint256 idleAfter) {
        if (!armed) revert NotArmed();
        if (marketId == bytes32(0)) revert NoMarket();

        uint256 debt = kingBorrowAssets();
        if (debt == 0) revert NoDebt();

        if (repayAmt == 0) {
            // Open enough idle to cover full deed (or all debt if smaller).
            uint256 want = deedAssets();
            uint256 already = idle();
            if (want > already) repayAmt = want - already;
            else repayAmt = 0;
            if (repayAmt > debt) repayAmt = debt;
        }
        if (repayAmt == 0) {
            idleAfter = idle();
            return idleAfter;
        }
        if (repayAmt > debt) repayAmt = debt;

        usdc.safeTransferFrom(msg.sender, address(this), repayAmt);
        morpho.accrueInterest(mp);
        morpho.repay(mp, repayAmt, 0, king, "");

        idleAfter = idle();
        if (idleAfter == 0) revert IdleMiss();

        totalRepaid += repayAmt;
        lastRepay = repayAmt;
        emit DeedUnmatched(repayAmt, idleAfter, utilBps());
    }

    function _peel(uint256 amt) internal returns (uint256 peeled) {
        if (yrss.allowance(king, address(this)) == 0) revert NeedApprove();
        uint256 maxW = yrss.maxWithdraw(king);
        if (maxW == 0) revert WithdrawMiss();
        peeled = amt == 0 || amt > maxW ? maxW : amt;
        uint256 before = usdc.balanceOf(landing);
        uint256 got = yrss.withdraw(peeled, landing, king);
        if (got < peeled) revert WithdrawMiss();
        if (usdc.balanceOf(landing) < before + peeled) revert LandingMiss();
        totalPeeled += peeled;
        lastPeel = peeled;
        emit DeedPeeled(peeled, usdc.balanceOf(landing), idle());
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
