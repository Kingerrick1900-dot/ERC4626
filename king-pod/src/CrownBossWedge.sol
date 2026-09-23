// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IMorphoW {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data)
        external;

    function borrow(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);

    function repay(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);

    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);

    function accrueInterest(MarketParams memory marketParams) external;
}

interface IYrssW {
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

interface IOracleW {
    function price() external view returns (uint256);
}

/// @title CrownBossWedge
/// @notice Engineer USDC wedge from HOT eUSD vs Boss book — drain ALL available USDC liquidity.
/// @dev Boss = USDC loan / eUSD coll. Does not invent liquidity; drains what the book has, then
///      repay-for park + peel yRSS. Vacuum: call again whenever boss idle refills.
contract CrownBossWedge is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    uint256 public constant ORACLE_SCALE = 1e36;
    uint256 public constant WAD = 1e18;
    uint256 public constant HAIRCUT_BPS = 9_500;
    uint256 public constant BPS = 10_000;

    IMorphoW public immutable morpho;
    IERC20 public immutable usdc;
    IERC20 public immutable eusd;
    IYrssW public immutable yrss;
    address public immutable king;
    address public landing;

    IMorphoW.MarketParams public mpBoss;
    IMorphoW.MarketParams public mpPark;
    bytes32 public bossId;
    bytes32 public parkId;

    bool public armed = true;
    uint256 public totalBorrowed;
    uint256 public totalPeeled;
    uint256 public lastBorrow;
    uint256 public lastPeel;

    event MarketsSet(bytes32 bossId, bytes32 parkId);
    event Armed(bool on);
    event LandingSet(address landing);
    event WedgeDrained(uint256 borrowed, uint256 repaidPark, uint256 peeled, uint256 bossIdleLeft);

    error KingOnly();
    error BadAmt();
    error NotArmed();
    error NoMarket();
    error IdleMiss();
    error WithdrawMiss();
    error LandingMiss();
    error NeedApprove();
    error NoBorrow();

    modifier onlyKing() {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        _;
    }

    constructor(
        address morpho_,
        address usdc_,
        address eusd_,
        address yrss_,
        address king_,
        address landing_,
        address owner_
    ) Ownable(owner_) {
        morpho = IMorphoW(morpho_);
        usdc = IERC20(usdc_);
        eusd = IERC20(eusd_);
        yrss = IYrssW(yrss_);
        king = king_;
        landing = landing_;
        usdc.safeApprove(morpho_, type(uint256).max);
        eusd.safeApprove(morpho_, type(uint256).max);
    }

    function setArmed(bool on) external onlyOwner {
        armed = on;
        emit Armed(on);
    }

    function setLanding(address landing_) external onlyOwner {
        if (landing_ == address(0)) revert BadAmt();
        landing = landing_;
        emit LandingSet(landing_);
    }

    function setMarkets(
        address rss,
        address oracleBoss,
        address oraclePark,
        address irm,
        uint256 lltvBoss,
        uint256 lltvPark,
        bytes32 bossId_,
        bytes32 parkId_
    ) external onlyOwner {
        mpBoss = IMorphoW.MarketParams(address(usdc), address(eusd), oracleBoss, irm, lltvBoss);
        mpPark = IMorphoW.MarketParams(address(usdc), rss, oraclePark, irm, lltvPark);
        bossId = bossId_;
        parkId = parkId_;
        emit MarketsSet(bossId_, parkId_);
    }

    function bossIdle() public view returns (uint256) {
        if (bossId == bytes32(0)) return 0;
        (uint128 s,, uint128 b,,,) = morpho.market(bossId);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    function parkIdle() public view returns (uint256) {
        if (parkId == bytes32(0)) return 0;
        (uint128 s,, uint128 b,,,) = morpho.market(parkId);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    function maxBorrowVsEusd(uint256 eusdAmt) public view returns (uint256) {
        if (mpBoss.lltv == 0 || mpBoss.oracle == address(0) || eusdAmt == 0) return 0;
        uint256 value = eusdAmt * IOracleW(mpBoss.oracle).price() / ORACLE_SCALE;
        return value * mpBoss.lltv / WAD * HAIRCUT_BPS / BPS;
    }

    /// @notice Drain ALL boss USDC idle vs eUSD coll → repay park → peel yRSS → Landing.
    /// @param eusdColl eUSD to post (0 = pull from king balance, sized for full idle).
    function drainWedge(uint256 eusdColl) external onlyKing nonReentrant returns (uint256 borrowed, uint256 peeled) {
        if (!armed) revert NotArmed();
        if (bossId == bytes32(0) || parkId == bytes32(0)) revert NoMarket();
        if (yrss.allowance(king, address(this)) == 0) revert NeedApprove();

        uint256 idle = bossIdle();
        if (idle == 0) revert IdleMiss();

        if (eusdColl == 0) {
            // size coll for full idle at haircut LLTV
            uint256 price = IOracleW(mpBoss.oracle).price();
            if (price == 0) revert BadAmt();
            uint256 num = idle * ORACLE_SCALE * WAD * BPS;
            uint256 den = price * mpBoss.lltv * HAIRCUT_BPS;
            eusdColl = (num + den - 1) / den;
            uint256 bal = eusd.balanceOf(king);
            if (eusdColl > bal) eusdColl = bal;
        }
        if (eusdColl == 0) revert BadAmt();

        eusd.safeTransferFrom(msg.sender, address(this), eusdColl);
        morpho.supplyCollateral(mpBoss, eusdColl, address(this), "");

        uint256 room = maxBorrowVsEusd(eusdColl);
        borrowed = idle < room ? idle : room;
        if (borrowed == 0) revert IdleMiss();

        morpho.borrow(mpBoss, borrowed, 0, address(this), address(this));
        totalBorrowed += borrowed;
        lastBorrow = borrowed;

        // repay-for king on park → open util
        morpho.accrueInterest(mpPark);
        morpho.repay(mpPark, borrowed, 0, king, "");

        uint256 maxW = yrss.maxWithdraw(king);
        peeled = maxW < borrowed ? maxW : borrowed;
        if (peeled == 0) revert WithdrawMiss();
        uint256 before = usdc.balanceOf(landing);
        uint256 got = yrss.withdraw(peeled, landing, king);
        if (got < peeled) revert WithdrawMiss();
        if (usdc.balanceOf(landing) < before + peeled) revert LandingMiss();

        totalPeeled += peeled;
        lastPeel = peeled;
        emit WedgeDrained(borrowed, borrowed, peeled, bossIdle());
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
