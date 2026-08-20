// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownRss1200Signal} from "../src/CrownRss1200Signal.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoT {
    function setAuthorization(address, bool) external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

/// @dev Fork: $200M matched signal with 250k RSS (HF 1.50), then self-del back to HOT.
contract Rss1200SignalForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MID = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    uint256 constant ASK = 200_000_000e6;
    uint256 constant COLL = 250_000 ether;

    function setUp() public {
        string memory rpc = vm.envOr("BASE_RPC_URL", string("https://mainnet.base.org"));
        vm.createSelectFork(rpc);
    }

    function _deploy() internal returns (CrownRss1200Signal z) {
        vm.startPrank(HOT);
        z = new CrownRss1200Signal(MORPHO, USDC, RSS, HOT, MID, ORACLE, IRM, LLTV);
        IMorphoT(MORPHO).setAuthorization(address(z), true);
        IERC20T(RSS).approve(address(z), COLL);
        IERC20T(USDC).approve(address(z), 2_000e6);
        deal(USDC, HOT, IERC20T(USDC).balanceOf(HOT) + 2_000e6);
        vm.stopPrank();
    }

    function test_headroom_refuses_all_rss() public {
        CrownRss1200Signal z = _deploy();
        uint256 dump = IERC20T(RSS).balanceOf(HOT);
        vm.startPrank(HOT);
        IERC20T(RSS).approve(address(z), dump);
        vm.expectRevert(CrownRss1200Signal.Headroom.selector);
        z.seed(ASK, dump);
        vm.stopPrank();
    }

    function test_seed_200m_then_self_del() public {
        uint256 flashPool = IERC20T(USDC).balanceOf(MORPHO);
        console2.log("morphoUsdc", flashPool);
        vm.skip(flashPool < ASK);

        uint256 rssBefore = IERC20T(RSS).balanceOf(HOT);
        assertGe(rssBefore, COLL + 1_000_000 ether, "need liquid RSS headroom");

        CrownRss1200Signal z = _deploy();

        vm.prank(HOT);
        z.seed(ASK, COLL);

        (uint256 sup, uint128 bor, uint128 collPos) = IMorphoT(MORPHO).position(MID, HOT);
        (uint128 tsa,, uint128 tba,,,) = IMorphoT(MORPHO).market(MID);
        uint256 hf = z.hfWad(uint256(collPos), uint256(tba));
        uint256 rssAfterSeed = IERC20T(RSS).balanceOf(HOT);

        console2.log("supplyAssets", uint256(tsa));
        console2.log("borrowAssets", uint256(tba));
        console2.log("hotCollRss", uint256(collPos));
        console2.log("hfWad", hf);
        console2.log("rssFreeAfterSeed", rssAfterSeed);

        assertGe(uint256(tba), ASK, "signal borrow");
        assertEq(uint256(collPos), COLL, "coll posted");
        assertGe(hf, 1.5e18, "hf headroom");
        assertGe(rssAfterSeed, 1_000_000 ether, "rss left liquid");
        assertEq(rssAfterSeed, rssBefore - COLL, "only coll locked");
        assertGt(sup, 0, "supply shares on HOT");
        assertGt(uint256(bor), 0, "borrow shares on HOT");

        // Self-del / self-liq — same chassis, auth already on.
        vm.prank(HOT);
        z.unwind();

        (uint256 sup2, uint128 bor2, uint128 coll2) = IMorphoT(MORPHO).position(MID, HOT);
        assertEq(sup2, 0, "sup clear");
        assertEq(uint256(bor2), 0, "bor clear");
        assertEq(uint256(coll2), 0, "coll clear");
        assertGe(IERC20T(RSS).balanceOf(HOT), rssBefore, "rss back");
        assertTrue(z.lastClosed(), "closed");
        console2.log("SELF_DEL_SET_OK", uint256(1));
    }

    function test_selfLiq_alias_clears() public {
        uint256 flashPool = IERC20T(USDC).balanceOf(MORPHO);
        vm.skip(flashPool < ASK);

        CrownRss1200Signal z = _deploy();
        uint256 rssBefore = IERC20T(RSS).balanceOf(HOT);

        vm.prank(HOT);
        z.seed(0, 0); // defaults

        vm.prank(HOT);
        z.selfLiq();

        (, uint128 bor, uint128 coll) = IMorphoT(MORPHO).position(MID, HOT);
        assertEq(uint256(bor), 0);
        assertEq(uint256(coll), 0);
        assertGe(IERC20T(RSS).balanceOf(HOT), rssBefore);
    }
}
