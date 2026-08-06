// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownMissionComplete} from "../src/CrownMissionComplete.sol";

interface IMorphoAuth {
    function setAuthorization(address, bool) external;
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

/// @notice Prove flash closes with ZERO prefunded USDC on hot (protocol-complete).
contract MissionCompleteFork is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant MID = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
    }

    function test_proto_close_zero_prefund_700k() public {
        uint256 ask = 700_000e6;

        vm.startPrank(HOT);
        CrownMissionComplete c = new CrownMissionComplete(MORPHO, USDC, HOT, LANDING, MID);
        IMorphoAuth(MORPHO).setAuthorization(address(c), true);
        // NO deal(USDC) — protocol close must work bare
        c.protoClose(ask);
        vm.stopPrank();

        console2.log("peakIdle", c.lastPeakIdle());
        console2.log("borrowedToRouter", c.lastBorrowedToRouter());
        console2.log("closed", c.lastClosed());
        assertGe(c.lastPeakIdle(), ask);
        assertEq(c.lastBorrowedToRouter(), ask);
        assertTrue(c.lastClosed());
    }

    function test_unlock_close_zero_prefund_700k() public {
        uint256 ask = 700_000e6;

        vm.startPrank(HOT);
        CrownMissionComplete c = new CrownMissionComplete(MORPHO, USDC, HOT, LANDING, MID);
        IMorphoAuth(MORPHO).setAuthorization(address(c), true);
        c.unlockClose(ask);
        vm.stopPrank();

        console2.log("peakIdle", c.lastPeakIdle());
        console2.log("closed", c.lastClosed());
        assertGe(c.lastPeakIdle(), ask);
        assertTrue(c.lastClosed());
    }
}
