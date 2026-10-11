// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownSovereignMigrate} from "../src/CrownSovereignMigrate.sol";
import {IMorphoMarket} from "../src/interfaces/IMorphoMarket.sol";

interface IMorphoS is IMorphoMarket {
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function idToMarketParams(bytes32 id) external view returns (address, address, address, address, uint256);
    function accrueInterest(MarketParams memory marketParams) external;
}

interface IERC20S {
    function balanceOf(address) external view returns (uint256);
}

interface IYrssS {
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IOracleS {
    function price() external view returns (uint256);
}

/// @notice Gap STRUCK. Path B max-free: flash + King yRSS. No treasury. No chase of minority $4.4M.
contract SimSovereignMigrateTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant LEGACY_ORACLE = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant LIVE_ORACLE = 0x22E2F66a26eA8d01E0Bb4154ef4DfB0304a34f2d;
    bytes32 constant LIVE_SOV = 0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant LEGACY = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;
    uint256 constant COLL = 252000000000000000000000;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
    }

    function test_path_b_gap_struck_max_free() public {
        assertLt(IERC20S(USDC).balanceOf(HOT), 1e6, "no treasury inject");

        (address loan,,,,) = IMorphoS(MORPHO).idToMarketParams(LIVE_SOV);
        assertEq(loan, USDC, "sovereign market live");

        (, uint128 bor0, uint128 coll0) = IMorphoS(MORPHO).position(LEGACY, HOT);
        assertEq(coll0, COLL);
        console2.log("legacyBorrowSharesBefore", bor0);

        CrownSovereignMigrate mig = new CrownSovereignMigrate(
            MORPHO,
            USDC,
            RSS,
            YRSS,
            HOT,
            LEGACY,
            LEGACY_ORACLE,
            LIVE_SOV,
            LIVE_ORACLE,
            IRM,
            LLTV,
            HOT
        );

        vm.startPrank(HOT);
        IYrssS(YRSS).approve(address(mig), type(uint256).max);
        IMorphoS(MORPHO).setAuthorization(address(mig), true);
        mig.migrate();
        vm.stopPrank();

        (, uint128 borLeg, uint128 collLeg) = IMorphoS(MORPHO).position(LEGACY, HOT);
        (, uint128 borSov, uint128 collSov) = IMorphoS(MORPHO).position(LIVE_SOV, HOT);

        console2.log("legacyBorrowSharesAfter", borLeg);
        console2.log("legacyCollAfter", collLeg);
        console2.log("sovereignColl", collSov);
        console2.log("sovereignBorrow", borSov);

        // Majority of RSS must land on sovereign — gap is not chased
        assertGt(collSov, (COLL * 85) / 100, ">=85% RSS freed to sovereign");
        assertEq(borSov, 0);
        assertEq(IOracleS(LIVE_ORACLE).price(), 50000000000000000000000000000);

        // Residual legacy (if any) must be healthy at LLTV
        if (borLeg > 0) {
            assertGt(collLeg, 0, "residual debt keeps some RSS");
            IMorphoMarket.MarketParams memory mp =
                IMorphoMarket.MarketParams(USDC, RSS, LEGACY_ORACLE, IRM, LLTV);
            IMorphoS(MORPHO).accrueInterest(mp);
            (,, uint128 tba, uint128 tbs,,) = IMorphoS(MORPHO).market(LEGACY);
            uint256 debt = (uint256(tba) * uint256(borLeg) + uint256(tbs) - 1) / uint256(tbs);
            uint256 px = IOracleS(LEGACY_ORACLE).price();
            uint256 collValue = uint256(collLeg) * px / 1e36;
            uint256 maxDebt = collValue * LLTV / 1e18;
            console2.log("residualDebt", debt);
            console2.log("residualMaxDebt", maxDebt);
            assertLe(debt, maxDebt, "residual healthy");
        } else {
            assertEq(collLeg, 0, "flat legacy if debt cleared");
            assertEq(collSov, COLL, "full 252k on sovereign");
        }
    }
}
