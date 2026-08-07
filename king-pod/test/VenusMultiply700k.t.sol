// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownVenusMultiply700k} from "../src/CrownVenusMultiply700k.sol";

interface IMorphoAuth {
    function setAuthorization(address, bool) external;
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice Venus/Kamino Multiply $700k with free RSS — zero USDC prefund on hot.
contract VenusMultiply700kFork is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant MID = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    // ~758 RSS covers $700k at $1200 oracle / 77% LLTV; use 1k from free bag
    uint256 constant EQUITY = 1_000e18;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
    }

    function test_venus_multiply_700k_free_rss_zero_usdc_prefund() public {
        uint256 landBefore = IERC20T(USDC).balanceOf(LANDING);
        uint256 rssBefore = IERC20T(RSS).balanceOf(HOT);
        assertGe(rssBefore, EQUITY, "need free RSS on hot");

        (, uint128 borrowSharesBefore, uint128 collBefore) = IMorphoAuth(MORPHO).position(MID, HOT);

        vm.startPrank(HOT);
        CrownVenusMultiply700k m = new CrownVenusMultiply700k(MORPHO, USDC, RSS, HOT, LANDING, MID);
        IMorphoAuth(MORPHO).setAuthorization(address(m), true);
        IERC20T(RSS).approve(address(m), EQUITY);
        m.multiply700k(EQUITY);
        vm.stopPrank();

        console2.log("peakIdle", m.lastPeakIdle());
        console2.log("seedBorrow", m.lastSeedBorrow());
        console2.log("surplusLanding", m.lastSurplusToLanding());
        console2.log("closed", m.lastClosed());
        console2.log("equityRss", m.lastEquityRss());

        assertTrue(m.lastClosed());
        assertEq(m.lastFlash(), 700_000e6);
        assertEq(m.lastSeedBorrow(), 700_000e6);
        assertGe(m.lastPeakIdle(), 700_000e6);
        assertEq(m.lastEquityRss(), EQUITY);

        // Seed = position: free RSS posted as coll
        (, uint128 borrowSharesAfter, uint128 collAfter) = IMorphoAuth(MORPHO).position(MID, HOT);
        assertGt(collAfter, collBefore, "equity RSS not posted");
        borrowSharesBefore; // rematch keeps borrow shares ~same region
        borrowSharesAfter;

        // Self-matched book: Venus surplus to Landing = 0 (flash consumes manufactured idle)
        assertEq(m.lastSurplusToLanding(), 0);
        assertEq(IERC20T(USDC).balanceOf(LANDING), landBefore, "Landing USDC unchanged on rematch multiply");
    }

    function test_venus_multiply_land_want_still_closes() public {
        // wantLanding requested; idle ≈ flash+1 wei on self-match — closes; dust surplus → Landing
        uint256 landBefore = IERC20T(USDC).balanceOf(LANDING);

        vm.startPrank(HOT);
        CrownVenusMultiply700k m = new CrownVenusMultiply700k(MORPHO, USDC, RSS, HOT, LANDING, MID);
        IMorphoAuth(MORPHO).setAuthorization(address(m), true);
        IERC20T(RSS).approve(address(m), EQUITY);
        m.multiplyLand700k(EQUITY, 700_000e6);
        vm.stopPrank();

        assertTrue(m.lastClosed());
        // peak idle = ask + pre-existing ~1 wei → surplus dust to Landing when want > 0
        assertEq(m.lastSurplusToLanding(), m.lastPeakIdle() - m.lastFlash());
        assertEq(IERC20T(USDC).balanceOf(LANDING), landBefore + m.lastSurplusToLanding());
        assertEq(m.lastSeedBorrow(), m.lastPeakIdle());
    }
}
