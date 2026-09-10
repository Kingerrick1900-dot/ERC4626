// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoUnlatch {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supply(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);

    function repay(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);

    function accrueInterest(MarketParams memory marketParams) external;
}

interface IYrssUnlatch {
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
}

/// @title CrownUnlatchIdle
/// @notice Engineer LASTING unmatched Morpho USDC idle. Never borrows. Never gasPark.
/// @dev Idle we don't have = unmatched supply − borrow. Two engineers:
///      1) engineerIdle: supply USDC direct → idle stays (minIdleBuffer protected)
///      2) unlatchRepay: repay king park debt → idle opens without cutting supply
///      peelSurplus: robots pull yRSS → Landing only ABOVE minIdleBuffer so idle stays unlatched.
contract CrownUnlatchIdle is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint256 public constant BPS = 10_000;
    uint256 public constant ASK_USDC = 2_000_000e6;

    IMorphoUnlatch public immutable morpho;
    IERC20 public immutable usdc;
    IYrssUnlatch public immutable yrss;
    address public immutable king;
    address public landing;

    IMorphoUnlatch.MarketParams public mp;
    bytes32 public marketId;

    /// @notice Idle that must remain unmatched after any peel (default = full ASK until lowered).
    uint256 public minIdleBuffer;
    bool public armed = true;

    uint256 public totalEngineered;
    uint256 public totalRepaid;
    uint256 public totalPeeled;
    uint256 public lastEngineer;
    uint256 public lastRepay;
    uint256 public lastPeel;

    event LandingSet(address landing);
    event MarketSet(bytes32 indexed id);
    event MinIdleBufferSet(uint256 buffer);
    event Armed(bool on);
    event IdleEngineered(uint256 supplied, uint256 idleAfter, uint256 utilBps);
    event IdleUnlatchedByRepay(uint256 repaid, uint256 idleAfter);
    event SurplusPeeled(uint256 peeled, uint256 idleLeft, uint256 landingBal);

    error KingOnly();
    error BadAmt();
    error NotArmed();
    error NoMarket();
    error IdleMiss();
    error BufferMiss();
    error WithdrawMiss();
    error LandingMiss();
    error BorrowGrew();
    error NoBorrow();
    error NoDebt();

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
        morpho = IMorphoUnlatch(morpho_);
        usdc = IERC20(usdc_);
        yrss = IYrssUnlatch(yrss_);
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

    function setMinIdleBuffer(uint256 buffer) external onlyOwner {
        minIdleBuffer = buffer;
        emit MinIdleBufferSet(buffer);
    }

    function setMarketRss(address rss, address oracle, address irm, uint256 lltv, bytes32 id) external onlyOwner {
        if (rss == address(0) || oracle == address(0) || irm == address(0) || id == bytes32(0)) revert BadAmt();
        mp = IMorphoUnlatch.MarketParams(address(usdc), rss, oracle, irm, lltv);
        marketId = id;
        emit MarketSet(id);
    }

    function idle() public view returns (uint256) {
        if (marketId == bytes32(0)) return 0;
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    function utilBps() public view returns (uint256) {
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        if (s == 0) return 0;
        return (uint256(b) * BPS) / uint256(s);
    }

    function surplusIdle() public view returns (uint256) {
        uint256 i = idle();
        return i > minIdleBuffer ? i - minIdleBuffer : 0;
    }

    function maxPeel() public view returns (uint256) {
        uint256 maxW = yrss.maxWithdraw(king);
        uint256 sur = surplusIdle();
        return maxW < sur ? maxW : sur;
    }

    function kingBorrowAssets() public view returns (uint256) {
        if (marketId == bytes32(0)) return 0;
        (, uint128 borShares,) = morpho.position(marketId, king);
        if (borShares == 0) return 0;
        (,, uint128 tba, uint128 tbs,,) = morpho.market(marketId);
        if (tbs == 0) return 0;
        return (uint256(tba) * uint256(borShares) + uint256(tbs) - 1) / uint256(tbs);
    }

    function fund(uint256 amt) external onlyKing nonReentrant {
        if (amt == 0) revert BadAmt();
        usdc.safeTransferFrom(msg.sender, address(this), amt);
    }

    /// @notice ENGINEER lasting unmatched idle: Morpho.supply direct. No borrow. Buffer rises.
    function engineerIdle(uint256 amt) external onlyKing nonReentrant returns (uint256 supplied) {
        if (!armed) revert NotArmed();
        if (marketId == bytes32(0)) revert NoMarket();

        (, uint128 borBefore,) = morpho.position(marketId, king);

        uint256 bal = usdc.balanceOf(address(this));
        if (amt == 0) amt = bal >= ASK_USDC ? ASK_USDC : bal;
        if (amt == 0) revert BadAmt();
        if (bal < amt) usdc.safeTransferFrom(msg.sender, address(this), amt - bal);

        uint256 idleBefore = idle();
        morpho.supply(mp, amt, 0, address(this), "");
        supplied = amt;

        (, uint128 borAfter,) = morpho.position(marketId, king);
        if (borAfter > borBefore) revert BorrowGrew();

        uint256 idleAfter = idle();
        if (idleAfter < idleBefore + amt - 1) revert IdleMiss(); // allow 1 wei dust

        // Raise buffer so peel cannot eat the idle we just engineered (unless owner lowers).
        if (minIdleBuffer < idleAfter) {
            minIdleBuffer = idleAfter;
            emit MinIdleBufferSet(minIdleBuffer);
        }

        totalEngineered += amt;
        lastEngineer = amt;
        emit IdleEngineered(amt, idleAfter, utilBps());
    }

    /// @notice Unlatch by cutting king park debt with real USDC — idle opens, supply untouched.
    function unlatchRepay(uint256 amt) external onlyKing nonReentrant returns (uint256 idleAfter) {
        if (!armed) revert NotArmed();
        if (marketId == bytes32(0)) revert NoMarket();
        if (amt == 0) revert BadAmt();

        uint256 debt = kingBorrowAssets();
        if (debt == 0) revert NoDebt();
        if (amt > debt) amt = debt;

        usdc.safeTransferFrom(msg.sender, address(this), amt);
        morpho.accrueInterest(mp);
        morpho.repay(mp, amt, 0, king, "");

        idleAfter = idle();
        if (idleAfter == 0) revert IdleMiss();

        if (minIdleBuffer < idleAfter) {
            minIdleBuffer = idleAfter;
            emit MinIdleBufferSet(minIdleBuffer);
        }

        totalRepaid += amt;
        lastRepay = amt;
        emit IdleUnlatchedByRepay(amt, idleAfter);
    }

    /// @notice Peel yRSS → Landing only above minIdleBuffer so engineered idle STAYS unlatched.
    function peelSurplus(uint256 amt) external onlyKing nonReentrant returns (uint256 peeled) {
        if (!armed) revert NotArmed();
        peeled = _peel(amt);
    }

    /// @notice Robot poke: peel surplus the instant maxWithdraw and surplusIdle allow.
    function pokePeel() external nonReentrant returns (uint256 peeled) {
        if (!armed) revert NotArmed();
        if (surplusIdle() == 0) revert BufferMiss();
        peeled = _peel(0);
    }

    function _peel(uint256 amt) internal returns (uint256 peeled) {
        uint256 cap = maxPeel();
        if (cap == 0) revert WithdrawMiss();
        peeled = amt == 0 || amt > cap ? cap : amt;

        uint256 before = usdc.balanceOf(landing);
        uint256 got = yrss.withdraw(peeled, landing, king);
        if (got < peeled) revert WithdrawMiss();
        if (usdc.balanceOf(landing) < before + peeled) revert LandingMiss();
        if (idle() < minIdleBuffer) revert BufferMiss();

        totalPeeled += peeled;
        lastPeel = peeled;
        emit SurplusPeeled(peeled, idle(), usdc.balanceOf(landing));
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
