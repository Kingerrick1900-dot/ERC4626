// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownOracle} from "../src/CrownOracle.sol";
import {CrownSovereignMigrate} from "../src/CrownSovereignMigrate.sol";
import {IMorphoMarket} from "../src/interfaces/IMorphoMarket.sol";

interface IMorphoS is IMorphoMarket {
    function createMarket(MarketParams memory marketParams) external;
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
    function maxWithdraw(address) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface IOracleS {
    function price() external view returns (uint256);
}

/// @notice Path B: flash + yRSS. No deal() of King treasury USDC. Path A forbidden.
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
    uint256 constant P50K = 50000000000000000000000000000;
    uint256 constant COLL = 252000000000000000000000;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
    }

    function test_path_b_self_fund_no_treasury() public {
        uint256 hotUsdcBefore = IERC20S(USDC).balanceOf(HOT);
        console2.log("hotUsdcBefore", hotUsdcBefore);
        assertLt(hotUsdcBefore, 1e6, "King has dust only - Path A forbidden");

        IMorphoMarket.MarketParams memory legacyMp =
            IMorphoMarket.MarketParams(USDC, RSS, LEGACY_ORACLE, IRM, LLTV);
        IMorphoS(MORPHO).accrueInterest(legacyMp);

        (, uint128 borBefore, uint128 collBefore) = IMorphoS(MORPHO).position(LEGACY, HOT);
        assertEq(collBefore, COLL);
        (,, uint128 tba, uint128 tbs,,) = IMorphoS(MORPHO).market(LEGACY);
        uint256 debt = (uint256(tba) * uint256(borBefore) + uint256(tbs) - 1) / uint256(tbs);
        uint256 kingYrss = IYrssS(YRSS).convertToAssets(IYrssS(YRSS).balanceOf(HOT));
        uint256 shareBps = (IYrssS(YRSS).balanceOf(HOT) * 10_000) / IYrssS(YRSS).totalSupply();

        console2.log("debt", debt);
        console2.log("kingYrssAssets", kingYrss);
        console2.log("hotYrssShareBps", shareBps);
        console2.log("morphoCash", IERC20S(USDC).balanceOf(MORPHO));
        console2.log("yrssMaxWithdrawBefore", IYrssS(YRSS).maxWithdraw(HOT));

        bytes32 sovId = LIVE_SOV;
        address oracle = LIVE_ORACLE;
        (address loan,,,,) = IMorphoS(MORPHO).idToMarketParams(sovId);
        if (loan == address(0)) {
            vm.startPrank(HOT);
            CrownOracle o = new CrownOracle(HOT, P50K);
            oracle = address(o);
            IMorphoMarket.MarketParams memory sovMp =
                IMorphoMarket.MarketParams(USDC, RSS, oracle, IRM, LLTV);
            IMorphoS(MORPHO).createMarket(sovMp);
            sovId = keccak256(abi.encode(sovMp));
            vm.stopPrank();
        }

        CrownSovereignMigrate mig = new CrownSovereignMigrate(
            MORPHO, USDC, RSS, YRSS, HOT, LEGACY, LEGACY_ORACLE, sovId, oracle, IRM, LLTV, HOT
        );

        vm.startPrank(HOT);
        IYrssS(YRSS).approve(address(mig), type(uint256).max);
        IMorphoS(MORPHO).setAuthorization(address(mig), true);

        if (kingYrss < debt) {
            console2.log("PRECHECK SystemShort: accrued debt exceeds King yRSS assets");
            vm.expectRevert(CrownSovereignMigrate.SystemShort.selector);
            mig.migrate();
            return;
        }

        mig.migrate();
        vm.stopPrank();

        (, uint128 borLegacy, uint128 collLegacy) = IMorphoS(MORPHO).position(LEGACY, HOT);
        (, uint128 borSov, uint128 collSov) = IMorphoS(MORPHO).position(sovId, HOT);
        assertEq(borLegacy, 0, "legacy borrow cleared");
        assertEq(collLegacy, 0, "legacy coll cleared");
        assertEq(collSov, COLL, "RSS on sovereign");
        assertEq(borSov, 0);

        assertEq(IOracleS(oracle).price(), P50K);
        uint256 collValue = (uint256(collSov) * P50K) / 1e36;
        console2.log("sovereignCollValueUsdc6", collValue);
        console2.log("paperLtvBpsIfSameDebt", (debt * 10_000) / collValue);
        assertLt((debt * 10_000) / collValue, 300);

        assertLt(IERC20S(USDC).balanceOf(HOT), 5_000_000e6, "no multi-million treasury burn");
    }
}
