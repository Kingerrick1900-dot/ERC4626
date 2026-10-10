// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

interface IERC20C {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoC {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);

    function supplyCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, bytes memory data)
        external;

    function borrow(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);

    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

interface IOracleC {
    function price() external view returns (uint256);
}

interface ISpoilsC {
    function takeSpoil(uint256 amount, bytes32 campaign) external returns (uint256);
    function book()
        external
        view
        returns (uint256 spoils, uint256 coldAmt, uint256 oceanAmt, uint256 hotAmt, uint256 cBps, uint256 oBps);
}

interface IBreakerC {
    function armed() external view returns (bool);
    function tripped() external view returns (bool);
}

/// @notice Phase 2: fork-fire the verified cbBTC/USDC idle path to success.
/// Market 0x9103… — ~$168M USDC idle. Post cbBTC → borrow USDC → HOT → Spoils Ocean split.
contract SimCbBtcIdlePhase2Test is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant CBBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant SPOILS = 0x4dBc59786790F3B7B6aB03730dD2Db7DC7feecd0;
    address constant DEEP = 0xDDe33827dbd0aC5Ed1a8A68eE5D95c829902679A;
    address constant COLD = 0xBb3c14bBacD639797cB5c537fde370d1b7195521;
    address constant BREAKER = 0xd92482bb8a4Ac2F6B80cd1583D2b7AcB630759A8;

    bytes32 constant CBBTC_MKT = 0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836;

    uint256 constant ASK_5M = 5_000_000e6;
    uint256 constant ASK_25M = 25_000_000e6;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
    }

    function test_phase2_cbbtc_idle_borrow_5m_to_hot() public {
        assertTrue(IBreakerC(BREAKER).armed(), "AMO6 armed");
        assertFalse(IBreakerC(BREAKER).tripped(), "AMO6 not tripped");

        (uint128 s0,, uint128 b0,,,) = IMorphoC(MORPHO).market(CBBTC_MKT);
        uint256 idle0 = uint256(s0) - uint256(b0);
        console2.log("idle USDC before", idle0);
        assertGe(idle0, ASK_5M, "idle must cover 5M");

        uint256 coll = _collForBorrow(ASK_5M);
        console2.log("cbBTC coll (8dp)", coll);

        uint256 hotBefore = IERC20C(USDC).balanceOf(HOT);
        _borrowToHot(ASK_5M, coll);

        uint256 hotAfter = IERC20C(USDC).balanceOf(HOT);
        console2.log("HOT USDC before", hotBefore);
        console2.log("HOT USDC after", hotAfter);
        assertEq(hotAfter - hotBefore, ASK_5M, "HOT received full 5M");

        (uint128 s1,, uint128 b1,,,) = IMorphoC(MORPHO).market(CBBTC_MKT);
        uint256 idle1 = uint256(s1) - uint256(b1);
        console2.log("idle USDC after", idle1);
        assertApproxEqAbs(idle0 - idle1, ASK_5M, 1e6, "idle dropped by ask");

        (, uint128 borShares, uint128 collBal) = IMorphoC(MORPHO).position(CBBTC_MKT, HOT);
        assertGt(uint256(borShares), 0, "borrow open");
        assertEq(uint256(collBal), coll, "coll posted");
        console2.log("MISSION phase2 5M borrow PASS");
    }

    function test_phase2_cbbtc_idle_borrow_25m_and_spoils_ocean() public {
        assertTrue(IBreakerC(BREAKER).armed(), "AMO6 armed");

        (uint128 s0,, uint128 b0,,,) = IMorphoC(MORPHO).market(CBBTC_MKT);
        uint256 idle0 = uint256(s0) - uint256(b0);
        assertGe(idle0, ASK_25M, "idle must cover 25M");

        uint256 coll = _collForBorrow(ASK_25M);
        uint256 deepBefore = IERC20C(USDC).balanceOf(DEEP);
        uint256 coldBefore = IERC20C(USDC).balanceOf(COLD);
        uint256 hotBefore = IERC20C(USDC).balanceOf(HOT);
        (uint256 spoilsBefore,,,,,) = ISpoilsC(SPOILS).book();

        _borrowToHot(ASK_25M, coll);
        assertEq(IERC20C(USDC).balanceOf(HOT) - hotBefore, ASK_25M, "HOT +25M");

        // Route through live Spoils (30 Cold / 50 Ocean / 20 HOT) — Ocean sink = DeepPull
        bytes32 campaign = bytes32("CBBTC_IDLE_P2");
        vm.startPrank(HOT);
        IERC20C(USDC).approve(SPOILS, ASK_25M);
        uint256 taken = ISpoilsC(SPOILS).takeSpoil(ASK_25M, campaign);
        vm.stopPrank();

        assertEq(taken, ASK_25M, "full spoil");
        (uint256 spoils, uint256 totalCold, uint256 totalOcean, uint256 totalHot,,) = ISpoilsC(SPOILS).book();
        uint256 toCold = (ASK_25M * 3000) / 10_000;
        uint256 toOcean = (ASK_25M * 5000) / 10_000;
        uint256 toHot = ASK_25M - toCold - toOcean;
        console2.log("spoils delta", spoils - spoilsBefore);
        console2.log("toCold", toCold);
        console2.log("toOcean", toOcean);
        console2.log("toHot", toHot);

        assertEq(spoils - spoilsBefore, ASK_25M, "spoil book +25M");
        assertEq(IERC20C(USDC).balanceOf(COLD) - coldBefore, toCold, "cold funded");
        assertEq(IERC20C(USDC).balanceOf(DEEP) - deepBefore, toOcean, "ocean DeepPull funded");
        assertEq(IERC20C(USDC).balanceOf(HOT), hotBefore + toHot, "HOT kept 20%");
        assertGe(totalCold + totalOcean + totalHot, ASK_25M, "book totals");

        console2.log("MISSION phase2 25M borrow + Spoils Ocean PASS");
    }

    function _borrowToHot(uint256 ask, uint256 coll) internal {
        (address loan, address collTok, address oracle, address irm, uint256 lltv) =
            IMorphoC(MORPHO).idToMarketParams(CBBTC_MKT);
        require(loan == USDC && collTok == CBBTC, "market");

        deal(CBBTC, HOT, coll);

        IMorphoC.MarketParams memory mp = IMorphoC.MarketParams({
            loanToken: loan, collateralToken: collTok, oracle: oracle, irm: irm, lltv: lltv
        });

        vm.startPrank(HOT);
        IERC20C(CBBTC).approve(MORPHO, coll);
        IMorphoC(MORPHO).supplyCollateral(mp, coll, HOT, "");
        (uint256 borrowed,) = IMorphoC(MORPHO).borrow(mp, ask, 0, HOT, HOT);
        vm.stopPrank();
        require(borrowed == ask, "borrow size");
    }

    /// @dev Morpho oracle: price scales collateral(8dp) → loan(6dp) with 1e36 factor.
    function _collForBorrow(uint256 askUsdc) internal view returns (uint256 collCbBtc) {
        (,, address oracle,, uint256 lltv) = IMorphoC(MORPHO).idToMarketParams(CBBTC_MKT);
        uint256 px = IOracleC(oracle).price(); // ~1e36-scaled
        // maxBorrow = coll * price / 1e36 * lltv / 1e18
        // coll = ask * 1e36 * 1e18 / (price * lltv) * buffer
        collCbBtc = (askUsdc * 1e36 * 1e18) / (px * lltv);
        collCbBtc = (collCbBtc * 115) / 100; // 15% buffer under 86% LLTV
        if (collCbBtc == 0) collCbBtc = 1;
    }
}
