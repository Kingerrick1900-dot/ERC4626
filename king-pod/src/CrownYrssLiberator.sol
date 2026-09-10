// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoLib {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function repay(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes memory data
    ) external returns (uint256, uint256);

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);

    function accrueInterest(MarketParams memory marketParams) external;
}

interface IYrssLib {
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
}

/// @title CrownYrssLiberator
/// @notice Use king yRSS shares the instant Morpho idle exists. Optional repay wedge opens idle.
/// @dev Does NOT gasPark. Does NOT borrow. Repay reduces king's matched debt → idle appears →
///      shares withdraw to Landing. Robots poke when idle > 0.
contract CrownYrssLiberator is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IMorphoLib public immutable morpho;
    IERC20 public immutable usdc;
    IYrssLib public immutable yrss;
    address public immutable king;
    address public landing;

    IMorphoLib.MarketParams public mp;
    bytes32 public marketId;
    bool public armed = true;

    uint256 public totalRepaid;
    uint256 public totalLiberated;
    uint256 public lastRepay;
    uint256 public lastLiberate;

    event LandingSet(address landing);
    event MarketSet(bytes32 indexed id);
    event Armed(bool on);
    event Repaid(uint256 amt, uint256 idleAfter);
    event Liberated(uint256 amt, uint256 landingBal);

    error KingOnly();
    error BadAmt();
    error NotArmed();
    error NoMarket();
    error IdleMiss();
    error WithdrawMiss();
    error LandingMiss();
    error NoDebt();
    error NoBorrow();

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
        morpho = IMorphoLib(morpho_);
        usdc = IERC20(usdc_);
        yrss = IYrssLib(yrss_);
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

    function setMarketRss(address rss, address oracle, address irm, uint256 lltv, bytes32 id) external onlyOwner {
        if (rss == address(0) || oracle == address(0) || irm == address(0) || id == bytes32(0)) revert BadAmt();
        mp = IMorphoLib.MarketParams(address(usdc), rss, oracle, irm, lltv);
        marketId = id;
        emit MarketSet(id);
    }

    function idle() public view returns (uint256) {
        if (marketId == bytes32(0)) return 0;
        (uint128 s,, uint128 b,,,) = morpho.market(marketId);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    function shareAssets() public view returns (uint256) {
        return yrss.convertToAssets(yrss.balanceOf(king));
    }

    function maxLiberate() public view returns (uint256) {
        return yrss.maxWithdraw(king);
    }

    function kingBorrowAssets() public view returns (uint256) {
        if (marketId == bytes32(0)) return 0;
        morpho; // silence
        (, uint128 borShares,) = morpho.position(marketId, king);
        if (borShares == 0) return 0;
        (,, uint128 tba, uint128 tbs,,) = morpho.market(marketId);
        if (tbs == 0) return 0;
        return (uint256(tba) * uint256(borShares) + uint256(tbs) - 1) / uint256(tbs);
    }

    /// @notice Wedge: repay king Morpho debt with real USDC → unmatched idle appears for shares.
    function repayToOpenIdle(uint256 amt) external onlyKing nonReentrant returns (uint256 idleAfter) {
        if (!armed) revert NotArmed();
        if (marketId == bytes32(0)) revert NoMarket();
        if (amt == 0) revert BadAmt();
        uint256 debt = kingBorrowAssets();
        if (debt == 0) revert NoDebt();
        if (amt > debt) amt = debt;

        usdc.safeTransferFrom(msg.sender, address(this), amt);
        morpho.accrueInterest(mp);
        morpho.repay(mp, amt, 0, king, "");
        totalRepaid += amt;
        lastRepay = amt;
        idleAfter = idle();
        emit Repaid(amt, idleAfter);
    }

    /// @notice Use shares NOW — pull unlocked yRSS assets to Landing.
    function liberateToLanding(uint256 amt) external onlyKing nonReentrant returns (uint256 pulled) {
        if (!armed) revert NotArmed();
        pulled = _liberate(amt);
    }

    /// @notice Robot poke: the instant idle + maxWithdraw > 0, dump shares → Landing.
    function pokeLiberate() external nonReentrant returns (uint256 pulled) {
        if (!armed) revert NotArmed();
        if (idle() == 0) revert IdleMiss();
        pulled = _liberate(0);
    }

    /// @notice One king tx: repay wedge then liberate shares to Landing.
    function repayAndLiberate(uint256 repayAmt, uint256 liberateAmt)
        external
        onlyKing
        nonReentrant
        returns (uint256 idleAfter, uint256 pulled)
    {
        if (!armed) revert NotArmed();
        if (marketId == bytes32(0)) revert NoMarket();
        if (repayAmt == 0) revert BadAmt();

        uint256 debt = kingBorrowAssets();
        if (debt == 0) revert NoDebt();
        if (repayAmt > debt) repayAmt = debt;

        usdc.safeTransferFrom(msg.sender, address(this), repayAmt);
        morpho.accrueInterest(mp);
        morpho.repay(mp, repayAmt, 0, king, "");
        totalRepaid += repayAmt;
        lastRepay = repayAmt;
        idleAfter = idle();
        emit Repaid(repayAmt, idleAfter);

        pulled = _liberate(liberateAmt);
    }

    function _liberate(uint256 amt) internal returns (uint256 pulled) {
        uint256 maxW = yrss.maxWithdraw(king);
        if (maxW == 0) revert WithdrawMiss();
        pulled = amt == 0 || amt > maxW ? maxW : amt;
        uint256 before = usdc.balanceOf(landing);
        uint256 got = yrss.withdraw(pulled, landing, king);
        if (got < pulled) revert WithdrawMiss();
        if (usdc.balanceOf(landing) < before + pulled) revert LandingMiss();
        totalLiberated += pulled;
        lastLiberate = pulled;
        emit Liberated(pulled, usdc.balanceOf(landing));
    }

    /// @dev Hard refuse borrow / gasPark — shares liberate only via repay + idle withdraw.
    function borrow(uint256) external pure {
        revert NoBorrow();
    }

    function gasPark(uint256, uint256) external pure {
        revert NoBorrow();
    }
}
