// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownSeamlessMission} from "../src/CrownSeamlessMission.sol";
import {CrownMissionComplete} from "../src/CrownMissionComplete.sol";

interface IMorphoAuth {
    function setAuthorization(address, bool) external;
}

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice Seamless LeverageRouter settle law — flash closes with ZERO USDC prefund on hot.
contract SeamlessMissionFork is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant MID = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
    }

    /// @dev Seamless perfection: close = debt on router. No deal(USDC). No hot buffer.
    function test_seamless_close_700k_zero_prefund() public {
        uint256 ask = 700_000e6;

        vm.startPrank(HOT);
        CrownSeamlessMission c = new CrownSeamlessMission(MORPHO, USDC, RSS, HOT, LANDING, MID);
        IMorphoAuth(MORPHO).setAuthorization(address(c), true);
        c.seamlessClose(ask, 0);
        vm.stopPrank();

        console2.log("peakIdle", c.lastPeakIdle());
        console2.log("debtOnRouter", c.lastDebtOnRouter());
        console2.log("surplusLanding", c.lastSurplusToLanding());
        console2.log("closed", c.lastClosed());

        assertGe(c.lastPeakIdle(), ask);
        assertGe(c.lastDebtOnRouter(), ask);
        assertTrue(c.lastClosed());
        // Self-matched book: Seamless surplus = 0 (idle consumed by flash close)
        assertEq(c.lastSurplusToLanding(), 0);
    }

    /// @dev Equity leg (Seamless collateralFromSender). King already holds free RSS — no free-tx required.
    function test_seamless_close_with_equity_rss() public {
        uint256 ask = 700_000e6;
        uint256 equity = 1_000e18; // 1k RSS — dust vs ~9.76M free on hot

        uint256 rssBefore = IERC20T(RSS).balanceOf(HOT);
        assertGe(rssBefore, equity, "hot missing free RSS - King must free first");

        vm.startPrank(HOT);
        CrownSeamlessMission c = new CrownSeamlessMission(MORPHO, USDC, RSS, HOT, LANDING, MID);
        IMorphoAuth(MORPHO).setAuthorization(address(c), true);
        IERC20T(RSS).approve(address(c), equity);
        c.seamlessClose(ask, equity);
        vm.stopPrank();

        assertTrue(c.lastClosed());
        assertEq(c.lastEquityRss(), equity);
        assertEq(c.lastSurplusToLanding(), 0);
    }

    /// @dev Proto-close companion still zero-prefund.
    function test_proto_close_companion_700k() public {
        uint256 ask = 700_000e6;
        vm.startPrank(HOT);
        CrownMissionComplete c = new CrownMissionComplete(MORPHO, USDC, HOT, LANDING, MID);
        IMorphoAuth(MORPHO).setAuthorization(address(c), true);
        c.protoClose(ask);
        vm.stopPrank();
        assertTrue(c.lastClosed());
        assertEq(c.lastBorrowedToRouter(), ask);
    }
}
