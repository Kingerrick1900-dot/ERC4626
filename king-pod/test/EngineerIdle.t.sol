// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownEngineerIdle} from "../src/CrownEngineerIdle.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoAuth {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

/// @notice Fork-prove CORRECT Morpho idle engineering on King's RSS/$1200 book.
contract EngineerIdleFork is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant MID = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    uint256 constant ASK = 700_000e6;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
    }

    function _idle() internal view returns (uint256) {
        (uint128 s,, uint128 b,,,) = IMorphoAuth(MORPHO).market(MID);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    function test_prove_idle_from_loan_book_700k() public {
        console2.log("idle before", _idle());

        vm.startPrank(HOT);
        CrownEngineerIdle eng = new CrownEngineerIdle(MORPHO, USDC, HOT, LANDING, MID);
        IMorphoAuth(MORPHO).setAuthorization(address(eng), true);
        eng.proveIdleFromLoanBook(ASK);
        vm.stopPrank();

        console2.log("peak idle engineered", eng.lastPeakIdle());
        console2.log("idle after", _idle());
        assertGe(eng.lastPeakIdle(), ASK, "peak idle miss");
        // Flash closed matched — lasting idle back near 0
        assertLt(_idle(), 1e6, "should rematch after prove");

        (uint256 peak, uint256 ask,, uint256 ts, bytes32 mid, bool ok) = eng.lastProof();
        console2.log("scribe peak", peak);
        console2.log("scribe ok", ok);
        assertTrue(ok, "scribe miss");
        assertGe(peak, ASK, "scribe peak");
        assertEq(ask, ASK, "scribe ask");
        assertEq(mid, MID, "scribe market");
        assertGt(ts, 0, "scribe ts");
    }

    function test_idle_then_loan_landing_700k() public {
        uint256 beforeLand = IERC20T(USDC).balanceOf(LANDING);
        console2.log("idle before", _idle());
        console2.log("Landing before", beforeLand);

        vm.startPrank(HOT);
        CrownEngineerIdle eng = new CrownEngineerIdle(MORPHO, USDC, HOT, LANDING, MID);
        IMorphoAuth(MORPHO).setAuthorization(address(eng), true);
        // Flash-close buffer = ask (CORRECT path needs these dollars once)
        deal(USDC, HOT, ASK);
        IERC20T(USDC).approve(address(eng), ASK);
        eng.idleThenLoanToLanding(ASK);
        vm.stopPrank();

        uint256 delta = IERC20T(USDC).balanceOf(LANDING) - beforeLand;
        console2.log("peak idle engineered", eng.lastPeakIdle());
        console2.log("Landing delta", delta);
        console2.log("idle after", _idle());

        assertGe(eng.lastPeakIdle(), ASK, "peak idle miss");
        assertEq(delta, ASK, "Landing miss");
        assertEq(eng.lastLandingCredit(), ASK, "credit miss");
    }

    function test_idle_from_unmatched_supply_700k() public {
        vm.startPrank(HOT);
        CrownEngineerIdle eng = new CrownEngineerIdle(MORPHO, USDC, HOT, LANDING, MID);
        deal(USDC, HOT, ASK);
        IERC20T(USDC).approve(address(eng), ASK);
        eng.idleFromUnmatchedSupply(ASK);
        vm.stopPrank();

        console2.log("lasting idle", _idle());
        console2.log("peak", eng.lastPeakIdle());
        assertGe(_idle(), ASK, "lasting idle miss");
        assertGe(eng.lastPeakIdle(), ASK, "peak miss");
    }
}
