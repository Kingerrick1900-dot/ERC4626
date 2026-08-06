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

/// @notice Morpho sees idle → Morpho loans. Position broadcast at $1M.
contract EngineerIdleFork is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant MID = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    uint256 constant ONE_M = 1_000_000e6;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
    }

    function _idle() internal view returns (uint256) {
        (uint128 s,, uint128 b,,,) = IMorphoAuth(MORPHO).market(MID);
        return uint256(s) > uint256(b) ? uint256(s) - uint256(b) : 0;
    }

    function test_broadcast_1M_idle_then_morpho_loans() public {
        console2.log("idle before", _idle());

        vm.startPrank(HOT);
        CrownEngineerIdle eng = new CrownEngineerIdle(MORPHO, USDC, HOT, LANDING, MID);
        IMorphoAuth(MORPHO).setAuthorization(address(eng), true);
        eng.broadcastIdleLoan(ONE_M);
        vm.stopPrank();

        console2.log("peak idle Morpho saw", eng.lastPeakIdle());
        console2.log("Morpho loaned", eng.lastLoan());
        (uint256 peak, uint256 ask,,,, bool ok) = eng.lastProof();
        assertTrue(ok);
        assertGe(peak, ONE_M, "idle numbers miss");
        assertEq(eng.lastLoan(), ONE_M, "loan miss");
        assertEq(ask, ONE_M);
    }

    function test_broadcast_1M_loan_to_landing() public {
        uint256 beforeLand = IERC20T(USDC).balanceOf(LANDING);

        vm.startPrank(HOT);
        CrownEngineerIdle eng = new CrownEngineerIdle(MORPHO, USDC, HOT, LANDING, MID);
        IMorphoAuth(MORPHO).setAuthorization(address(eng), true);
        deal(USDC, HOT, ONE_M);
        IERC20T(USDC).approve(address(eng), ONE_M);
        eng.broadcastIdleLoanToLanding(ONE_M);
        vm.stopPrank();

        uint256 delta = IERC20T(USDC).balanceOf(LANDING) - beforeLand;
        console2.log("peak idle", eng.lastPeakIdle());
        console2.log("Landing delta", delta);
        assertGe(eng.lastPeakIdle(), ONE_M);
        assertEq(delta, ONE_M);
    }

    function test_prove_idle_from_loan_book_700k() public {
        // back-compat alias
        vm.startPrank(HOT);
        CrownEngineerIdle eng = new CrownEngineerIdle(MORPHO, USDC, HOT, LANDING, MID);
        IMorphoAuth(MORPHO).setAuthorization(address(eng), true);
        eng.proveIdleFromLoanBook(700_000e6);
        vm.stopPrank();
        assertGe(eng.lastPeakIdle(), 700_000e6);
        (,,,,, bool ok) = eng.lastProof();
        assertTrue(ok);
    }
}
