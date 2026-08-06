// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownRssUsdcLoop} from "../src/CrownRssUsdcLoop.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoT {
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

/// @notice RSS loop (no ETH). Equity = free RSS. Measure Landing USDC.
contract RssUsdcLoopFork is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant MID = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    function test_rss_loop_700k_ask() public {
        uint256 rssIn = 1_000_000e18; // free RSS on hot — loop equity, NOT eth
        uint256 flash = 700_000e6;
        uint256 land = 700_000e6;

        uint256 before_ = IERC20T(USDC).balanceOf(LANDING);
        (uint128 s0,, uint128 b0,,,) = IMorphoT(MORPHO).market(MID);
        console2.log("idle before", uint256(s0) - uint256(b0));

        vm.startPrank(HOT);
        CrownRssUsdcLoop loop = new CrownRssUsdcLoop(MORPHO, USDC, RSS, HOT, LANDING, MID);
        IERC20T(RSS).approve(address(loop), rssIn);
        loop.loop(rssIn, flash, land);
        vm.stopPrank();

        uint256 delta = IERC20T(USDC).balanceOf(LANDING) - before_;
        console2.log("RSS_LOOP Landing delta", delta);
        console2.log("flash", loop.lastFlash());
        console2.log("borrow", loop.lastBorrow());
        console2.log("idle", loop.lastIdle());
        console2.log("rssLooped", loop.lastRssLooped());
        console2.log("credit", loop.lastLandingCredit());
    }

    function test_rss_loop_migrate_only() public {
        uint256 rssIn = 100_000e18;
        uint256 flash = 700_000e6;
        uint256 before_ = IERC20T(USDC).balanceOf(LANDING);

        vm.startPrank(HOT);
        CrownRssUsdcLoop loop = new CrownRssUsdcLoop(MORPHO, USDC, RSS, HOT, LANDING, MID);
        IERC20T(RSS).approve(address(loop), rssIn);
        loop.loop(rssIn, flash, 0);
        vm.stopPrank();

        console2.log("MIGRATE Landing delta", IERC20T(USDC).balanceOf(LANDING) - before_);
        console2.log("borrow", loop.lastBorrow());
        assertEq(loop.lastBorrow(), loop.lastFlash());
    }
}
