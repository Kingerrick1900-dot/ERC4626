// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownSeedLand} from "../src/CrownSeedLand.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoAuth {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}

/// @notice Fork-prove: flash F + buffer want → supply → RSS coll → borrow F+want → Landing +$700k.
contract SeedLandFork is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant MID = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    uint256 constant WANT = 700_000e6;
    uint256 constant RSS_COLL = 5_000e18;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
    }

    function test_seedLand_borrow_gt_flash_Landing_700k() public {
        uint256 beforeLand = IERC20T(USDC).balanceOf(LANDING);
        uint256 hotRss = IERC20T(RSS).balanceOf(HOT);
        assertGe(hotRss, RSS_COLL, "need free RSS");

        // Buffer = want (becomes Morpho supply). Live hot lacks this — fork proves mechanism.
        deal(USDC, HOT, WANT);

        vm.startPrank(HOT);
        CrownSeedLand gun = new CrownSeedLand(MORPHO, USDC, RSS, HOT, LANDING, MID);
        IMorphoAuth(MORPHO).setAuthorization(address(gun), true);
        IERC20T(RSS).approve(address(gun), RSS_COLL);
        IERC20T(USDC).approve(address(gun), WANT);
        gun.seedLand(RSS_COLL, WANT, WANT); // flash F=want, borrow 2*want
        vm.stopPrank();

        uint256 delta = IERC20T(USDC).balanceOf(LANDING) - beforeLand;
        console2.log("flash", gun.lastFlash());
        console2.log("borrowed", gun.lastBorrowed());
        console2.log("peak idle", gun.lastPeakIdle());
        console2.log("Landing delta", delta);

        assertEq(gun.lastFlash(), WANT, "flash");
        assertEq(gun.lastBorrowed(), 2 * WANT, "borrow > flash");
        assertGe(gun.lastPeakIdle(), 2 * WANT, "idle");
        assertEq(delta, WANT, "Landing 700k");

        (, uint128 bor, uint128 coll) = IMorphoAuth(MORPHO).position(MID, HOT);
        assertGt(uint256(bor), 0, "debt seeded");
        assertEq(uint256(coll), RSS_COLL, "rss coll");
    }
}
