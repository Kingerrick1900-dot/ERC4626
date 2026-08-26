// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MorphoRssOracle} from "../src/MorphoRssOracle.sol";
import {
    SovereignIdleFactory,
    CrownSovereignAmoFleet,
    SupplyAmoBot
} from "../src/fleet/CrownFleetCore.sol";
import {TollBoothAutoSeeder, NoteIssuerAuto, CrownScrollRss} from "../src/fleet/CrownFleetRails.sol";
import {CrownGoldUsd} from "../src/CrownGoldUsd.sol";
import {CrownSovereignAmo} from "../src/CrownSovereignAmo.sol";
import {CrownSyncRedeem8020} from "../src/stack/CrownSyncRedeem8020.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function mint(address to, uint256 amt) external;
    function isMinter(address) external view returns (bool);
}

interface IMorphoT {
    function setAuthorization(address, bool) external;
}

contract CrownFleetFork is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant GUSD = 0x319A49BB274A826F889C6e7221FA82f24ac8bc5d;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant GATE = 0xab2856626BBd8E6fba9dB93783029eB973E8427F;
    address constant ORACLE50 = 0x264f7AfB8f12028345B87FD5E58F2CF444EebA90;
    address constant PSM = 0xF7337A26d9456e42a36531A12036A4556EF1F987;
    address constant AMO_EUSD = 0x8960BdbE760E6C90c53a912063170a2Efb1df4Ed;
    bytes32 constant MID_EUSD = 0x6075ba260df7fd5ad5bc9f1de33ac0bc2d8201dbe44b0081e89d9974f179867b;
    uint256 constant LLTV = 770000000000000000;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
    }

    function test_factory_opens_parallel_book_and_print_tick() public {
        vm.startPrank(HOT);
        SovereignIdleFactory factory = new SovereignIdleFactory(MORPHO, RSS, GATE, HOT, LANDING, IRM, LLTV, HOT);
        factory.registerBook(MID_EUSD, EUSD, ORACLE50, AMO_EUSD, address(0), false);
        MorphoRssOracle o = new MorphoRssOracle(50_000);
        (bytes32 mid, address amo,) = factory.openBook(EUSD, address(o), false);
        assertTrue(factory.bookCount() >= 2);
        IMorphoT(MORPHO).setAuthorization(amo, true);
        vm.stopPrank();

        // Fleet AMO: landing owner sets operator + gate off, funds supply
        uint256 mintAmt = 5_000_000e18;
        vm.prank(LANDING);
        CrownSovereignAmoFleet(amo).setRequireGate(false);
        vm.prank(LANDING);
        CrownSovereignAmoFleet(amo).setOperator(HOT, true);

        vm.prank(HOT);
        IERC20T(EUSD).mint(LANDING, mintAmt);
        vm.prank(LANDING);
        IERC20T(EUSD).approve(amo, mintAmt);
        vm.prank(HOT);
        CrownSovereignAmoFleet(amo).supplyAmo(LANDING, mintAmt);
        assertGe(CrownSovereignAmoFleet(amo).idle(), mintAmt);

        // Peel RSS + borrow
        // Use free deal RSS for fleet book coll (don't disturb live book in this unit)
        deal(RSS, HOT, 10_000 ether);
        vm.startPrank(HOT);
        IERC20T(RSS).approve(amo, 10_000 ether);
        CrownSovereignAmoFleet(amo).postCollateral(10_000 ether);
        uint256 ask = (CrownSovereignAmoFleet(amo).idle() * 7000) / 10_000;
        CrownSovereignAmoFleet(amo).borrowLoan(ask, HOT);
        vm.stopPrank();
        assertGe(IERC20T(EUSD).balanceOf(HOT), ask);
        console2.logBytes32(mid);
        console2.log("fleetIdle", CrownSovereignAmoFleet(amo).idle());
    }

    function test_legacy_print_tick_wraps_gusd() public {
        require(IERC20T(EUSD).isMinter(HOT), "minter");
        uint256 g0 = IERC20T(GUSD).balanceOf(HOT);
        uint256 mintAmt = 10_000_000e18;

        vm.prank(HOT);
        IERC20T(EUSD).mint(LANDING, mintAmt);
        vm.prank(LANDING);
        IERC20T(EUSD).approve(AMO_EUSD, mintAmt);

        CrownSovereignAmo amo = CrownSovereignAmo(AMO_EUSD);
        vm.startPrank(HOT);
        amo.supplyAmo(LANDING, mintAmt);
        uint256 ask = (amo.idle() * 7000) / 10_000;
        uint256 e0 = IERC20T(EUSD).balanceOf(HOT);
        amo.borrowEusd(ask, HOT);
        uint256 got = IERC20T(EUSD).balanceOf(HOT) - e0;
        uint256 wrapAmt = (got * 9000) / 10_000;
        IERC20T(EUSD).approve(GUSD, wrapAmt);
        CrownGoldUsd(GUSD).wrap(wrapAmt, HOT);
        vm.stopPrank();

        assertEq(IERC20T(GUSD).balanceOf(HOT), g0 + wrapAmt);
        console2.log("hotGusd", IERC20T(GUSD).balanceOf(HOT));
    }

    function test_seeder_and_notes_gates() public {
        vm.startPrank(HOT);
        TollBoothAutoSeeder seeder = new TollBoothAutoSeeder(EUSD, USDC, GUSD, PSM, HOT, HOT);
        seeder.setParams(200_000_000e18, 2_000_000e18, 10_000_000e6, 10); // trigger under live HOT
        seeder.setArmed(true);
        assertTrue(seeder.canSeed());
        vm.expectRevert(TollBoothAutoSeeder.NeedFx.selector);
        seeder.execSeed();

        bytes32 midUsdc = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;
        NoteIssuerAuto notes = new NoteIssuerAuto(RSS, PSM, HOT, MORPHO, midUsdc, HOT);
        notes.setArmed(true);
        uint256 cap = notes.borrowCapacity();
        console2.log("borrowCapacity", cap);
        // Capacity-backed: canIssue when Morpho headroom ≥ 10M USDC (not PSM dust)
        assertTrue(cap >= 10_000_000e6, "capacity < 10M");
        assertTrue(notes.canIssue(), "canIssue should be true on capacity");
        vm.stopPrank();
    }

    function test_8020_maxRedeem_uses_borrow_capacity() public {
        vm.startPrank(HOT);
        CrownSyncRedeem8020 sync = new CrownSyncRedeem8020(EUSD, GUSD, PSM, USDC, HOT);
        bytes32 midUsdc = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;
        sync.wireCapacity(MORPHO, midUsdc, HOT);
        uint256 cap = sync.borrowCapacityUsdc();
        uint256 maxE = sync.maxRedeemSync(HOT);
        assertEq(maxE, cap * 1e12, "maxRedeem != capacity");
        assertGe(cap, 10_000_000e6, "cap");
        console2.log("maxRedeemSync", maxE);
        vm.stopPrank();
    }

    function test_scroll_rss_token_genesis() public {
        CrownScrollRss rss = new CrownScrollRss(HOT, HOT, 21_000_000_000 ether);
        assertEq(rss.symbol(), "RSS");
        assertEq(rss.balanceOf(HOT), 21_000_000_000 ether);
        MorphoRssOracle o = new MorphoRssOracle(50_000);
        assertEq(o.dollarsPerRss(), 50_000);
    }
}
