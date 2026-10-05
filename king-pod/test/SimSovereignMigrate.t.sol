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
}

interface IERC20S {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IYrssS {
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IOracleS {
    function price() external view returns (uint256);
}

/// @notice Fork proof: legacy 252k RSS → King CrownOracle market.
contract SimSovereignMigrateTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant LEGACY_ORACLE = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant LEGACY = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;
    uint256 constant P50K = 50000000000000000000000000000;
    uint256 constant COLL = 252000000000000000000000;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
    }

    function _deployOracleAndMarket() internal returns (CrownOracle oracle, bytes32 sovId) {
        vm.startPrank(HOT);
        oracle = new CrownOracle(HOT, P50K);
        IMorphoMarket.MarketParams memory sovMp =
            IMorphoMarket.MarketParams(USDC, RSS, address(oracle), IRM, LLTV);
        IMorphoS(MORPHO).createMarket(sovMp);
        sovId = keccak256(abi.encode(sovMp));
        vm.stopPrank();
    }

    function _deployMigrator(bytes32 sovId, address oracle) internal returns (CrownSovereignMigrate mig) {
        mig = new CrownSovereignMigrate(
            MORPHO, USDC, RSS, YRSS, HOT, LEGACY, LEGACY_ORACLE, sovId, oracle, IRM, LLTV, HOT
        );
    }

    function _assertMigrated(bytes32 sovId, address oracle) internal view {
        (, uint128 borLegacy, uint128 collLegacy) = IMorphoS(MORPHO).position(LEGACY, HOT);
        (, uint128 borSov, uint128 collSov) = IMorphoS(MORPHO).position(sovId, HOT);
        assertEq(borLegacy, 0, "legacy borrow cleared");
        assertEq(collLegacy, 0, "legacy coll cleared");
        assertEq(collSov, COLL, "RSS on sovereign market");
        assertEq(borSov, 0, "no re-borrow in migrate");
        assertEq(IOracleS(oracle).price(), P50K);
        uint256 collValue = (uint256(collSov) * P50K) / 1e36;
        uint256 ltvBps = (257_294_976e6 * 10_000) / collValue;
        console2.log("sovereignCollValueUsdc6", collValue);
        console2.log("paperLtvBpsAt50kIf257MDebt", ltvBps);
        assertLt(ltvBps, 300, "under 3% LTV at commanded oracle");
    }

    /// @notice Path A: King treasury holds full debt USDC (no flash).
    function test_sovereign_migration() public {
        (, uint128 borBefore, uint128 collBefore) = IMorphoS(MORPHO).position(LEGACY, HOT);
        console2.log("legacyBorrowShares", borBefore);
        console2.log("legacyColl", collBefore);
        assertEq(collBefore, COLL, "expected 252k RSS on legacy");

        (CrownOracle oracle, bytes32 sovId) = _deployOracleAndMarket();
        deal(USDC, HOT, 300_000_000e6);

        CrownSovereignMigrate mig = _deployMigrator(sovId, address(oracle));
        vm.startPrank(HOT);
        IERC20S(USDC).approve(address(mig), type(uint256).max);
        IYrssS(YRSS).approve(address(mig), type(uint256).max);
        IMorphoS(MORPHO).setAuthorization(address(mig), true);
        mig.migrate();
        vm.stopPrank();

        _assertMigrated(sovId, address(oracle));
    }

    /// @notice Path B: Morpho flash + King treasury delta only (~flash shortfall).
    function test_sovereign_migration_flash_treasury_bridge() public {
        (, uint128 bor, uint128 coll) = IMorphoS(MORPHO).position(LEGACY, HOT);
        assertEq(coll, COLL);
        (,, uint128 tba, uint128 tbs,,) = IMorphoS(MORPHO).market(LEGACY);
        uint256 debt = (uint256(tba) * uint256(bor) + uint256(tbs) - 1) / uint256(tbs);
        uint256 morphoCash = IERC20S(USDC).balanceOf(MORPHO);
        uint256 flashAmt = debt < morphoCash ? debt : morphoCash;
        uint256 delta = debt - flashAmt;
        console2.log("debt", debt);
        console2.log("flashAmt", flashAmt);
        console2.log("treasuryDelta", delta);
        assertGt(delta, 0, "expect flash shortfall vs Morpho cash");

        (CrownOracle oracle, bytes32 sovId) = _deployOracleAndMarket();
        // Seed delta + buffer (accrueInterest can widen debt between estimate and migrate)
        deal(USDC, HOT, delta + 50_000_000e6);

        CrownSovereignMigrate mig = _deployMigrator(sovId, address(oracle));
        vm.startPrank(HOT);
        IERC20S(USDC).approve(address(mig), type(uint256).max);
        IYrssS(YRSS).approve(address(mig), type(uint256).max);
        IMorphoS(MORPHO).setAuthorization(address(mig), true);
        mig.migrate();
        vm.stopPrank();

        _assertMigrated(sovId, address(oracle));
    }
}
