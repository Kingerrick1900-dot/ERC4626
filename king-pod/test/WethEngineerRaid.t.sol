// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownPermissionlessWethSeed} from "../src/CrownPermissionlessWethSeed.sol";
import {CrownWethIdleRaid} from "../src/CrownWethIdleRaid.sol";
import {CrownRssWethDesk} from "../src/CrownRssWethDesk.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoAuth {
    function setAuthorization(address, bool) external;
}

/// @notice Engineer WETH via open fill / desk, then raid idle → Landing +$700k.
contract WethEngineerRaidFork is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ORACLE_RSS = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;
    address constant ORACLE_WETH = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    bytes32 constant WETH_MID = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;

    uint256 constant WANT = 700_000e6;
    uint256 constant EQUITY = 360 ether;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC_URL", string("https://mainnet.base.org")));
    }

    function test_permissionless_fill_then_raid_lands_700k() public {
        address filler = makeAddr("filler");

        vm.startPrank(HOT);
        CrownWethIdleRaid raid = new CrownWethIdleRaid(MORPHO, USDC, WETH, HOT, LANDING, WETH_MID);
        IMorphoAuth(MORPHO).setAuthorization(address(raid), true);

        CrownPermissionlessWethSeed seed =
            new CrownPermissionlessWethSeed(RSS, WETH, ORACLE_RSS, ORACLE_WETH, HOT, HOT, 2_000);

        uint256 needRss = seed.quoteRssOut(EQUITY);
        // ensure hot has escrow RSS
        deal(RSS, HOT, needRss);
        IERC20T(RSS).approve(address(seed), needRss);
        seed.depositRss(needRss);
        vm.stopPrank();

        // filler brings WETH (open market engineer)
        deal(WETH, filler, EQUITY);
        uint256 hotWethBefore = IERC20T(WETH).balanceOf(HOT);
        vm.startPrank(filler);
        IERC20T(WETH).approve(address(seed), EQUITY);
        uint256 rssOut = seed.fill(EQUITY);
        vm.stopPrank();

        assertEq(IERC20T(WETH).balanceOf(HOT), hotWethBefore + EQUITY, "WETH sunk to hot");
        assertGt(rssOut, 0, "filler got RSS");

        uint256 landBefore = IERC20T(USDC).balanceOf(LANDING);
        vm.startPrank(HOT);
        IERC20T(WETH).approve(address(raid), EQUITY);
        raid.raid(EQUITY, WANT);
        vm.stopPrank();

        uint256 delta = IERC20T(USDC).balanceOf(LANDING) - landBefore;
        console2.log("landingDelta", delta);
        assertEq(delta, WANT, "Landing MUST hit 700k");
    }

    function test_desk_fund_draw_then_raid_lands_700k() public {
        address lender = makeAddr("lender");

        vm.startPrank(HOT);
        CrownWethIdleRaid raid = new CrownWethIdleRaid(MORPHO, USDC, WETH, HOT, LANDING, WETH_MID);
        IMorphoAuth(MORPHO).setAuthorization(address(raid), true);
        CrownRssWethDesk desk = new CrownRssWethDesk(RSS, WETH, ORACLE_RSS, ORACLE_WETH, HOT, 0.75e18);
        vm.stopPrank();

        deal(WETH, lender, EQUITY);
        vm.startPrank(lender);
        IERC20T(WETH).approve(address(desk), EQUITY);
        desk.fund(EQUITY);
        vm.stopPrank();

        // ~360 WETH @ ~$2300 ≈ $828k; at 75% LTV need ~$1.104M RSS ≈ 920 RSS @ $1200
        uint256 rssLock = 1_000 ether;
        deal(RSS, HOT, rssLock);

        vm.startPrank(HOT);
        IERC20T(RSS).approve(address(desk), rssLock);
        desk.draw(rssLock, EQUITY, HOT);

        uint256 landBefore = IERC20T(USDC).balanceOf(LANDING);
        IERC20T(WETH).approve(address(raid), EQUITY);
        raid.raid(EQUITY, WANT);
        vm.stopPrank();

        assertEq(IERC20T(USDC).balanceOf(LANDING) - landBefore, WANT, "Landing MUST hit 700k");
    }

    function test_raid_eth_wrap_lands_700k() public {
        vm.deal(HOT, EQUITY);
        vm.startPrank(HOT);
        CrownWethIdleRaid raid = new CrownWethIdleRaid(MORPHO, USDC, WETH, HOT, LANDING, WETH_MID);
        IMorphoAuth(MORPHO).setAuthorization(address(raid), true);
        uint256 landBefore = IERC20T(USDC).balanceOf(LANDING);
        raid.raidEth{value: EQUITY}(WANT);
        vm.stopPrank();
        assertEq(IERC20T(USDC).balanceOf(LANDING) - landBefore, WANT, "Landing MUST hit 700k");
    }
}
