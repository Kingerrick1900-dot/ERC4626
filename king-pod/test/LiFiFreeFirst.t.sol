// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownLiFiFreeFirst} from "../src/CrownLiFiFreeFirst.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoT {
    function setAuthorization(address, bool) external;
}

contract LiFiFreeFirstFork is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant MID = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    CrownLiFiFreeFirst m;

    function setUp() public {
        vm.prank(HOT);
        m = new CrownLiFiFreeFirst(MORPHO, USDC, RSS, HOT, LANDING, MID);
        vm.prank(HOT);
        IMorphoT(MORPHO).setAuthorization(address(m), true);
    }

    function test_free_first_migrate_only() public {
        uint256 before_ = IERC20T(USDC).balanceOf(LANDING);
        vm.prank(HOT);
        m.runFreeFirst(700_000e6, 0, 0);
        uint256 delta = IERC20T(USDC).balanceOf(LANDING) - before_;
        console2.log("MIGRATE_ONLY Landing delta", delta);
        console2.log("flash", m.lastFlash());
        console2.log("borrow", m.lastBorrow());
        console2.log("rssEquity", m.lastRssEquity());
        console2.log("idle", m.lastIdle());
        console2.log("credit", m.lastLandingCredit());
        assertEq(m.lastBorrow(), m.lastFlash());
        assertEq(delta, 0);
    }

    function test_free_first_try_landing_700k() public {
        uint256 before_ = IERC20T(USDC).balanceOf(LANDING);
        uint256 extra = 1_000_000e18;
        vm.startPrank(HOT);
        IERC20T(RSS).approve(address(m), extra);
        m.runFreeFirst(700_000e6, extra, 700_000e6);
        vm.stopPrank();
        uint256 delta = IERC20T(USDC).balanceOf(LANDING) - before_;
        console2.log("TRY_700K Landing delta", delta);
        console2.log("flash", m.lastFlash());
        console2.log("borrow", m.lastBorrow());
        console2.log("rssEquity", m.lastRssEquity());
        console2.log("idle", m.lastIdle());
        console2.log("credit", m.lastLandingCredit());
        // Honest: idle==flash ⇒ borrow capped at flash ⇒ Landing 0
        assertEq(delta, m.lastLandingCredit());
    }

    function test_free_first_with_extra_rss_equity() public {
        // Extra free RSS increases LTV room but NOT idle — Landing still 0
        uint256 before_ = IERC20T(USDC).balanceOf(LANDING);
        uint256 extra = 5_000_000e18;
        vm.startPrank(HOT);
        IERC20T(RSS).approve(address(m), extra);
        m.runFreeFirst(5_000_000e6, extra, 700_000e6);
        vm.stopPrank();
        console2.log("EXTRA_RSS Landing delta", IERC20T(USDC).balanceOf(LANDING) - before_);
        console2.log("flash", m.lastFlash());
        console2.log("borrow", m.lastBorrow());
        console2.log("idle", m.lastIdle());
        console2.log("credit", m.lastLandingCredit());
    }
}
