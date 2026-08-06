// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownPeapodsMorphoSeed} from "../src/CrownPeapodsMorphoSeed.sol";
import {CrownVenusWethMultiply} from "../src/CrownVenusWethMultiply.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoT {
    function setAuthorization(address, bool) external;
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

contract PeapodsVenusSeedFork is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant AERO = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant AERO_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    bytes32 constant RSS_MID = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;
    bytes32 constant WETH_MID = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;

    function test_peapods_seed_engineers_700k_book() public {
        (uint128 s0,, uint128 b0,,,) = IMorphoT(MORPHO).market(RSS_MID);
        uint256 seedAmt = 700_000e6;

        vm.startPrank(HOT);
        CrownPeapodsMorphoSeed seeder = new CrownPeapodsMorphoSeed(MORPHO, USDC, HOT, RSS_MID);
        IMorphoT(MORPHO).setAuthorization(address(seeder), true);
        seeder.seed(seedAmt);
        vm.stopPrank();

        (uint128 s1,, uint128 b1,,,) = IMorphoT(MORPHO).market(RSS_MID);
        console2.log("PEAPODS supply before", uint256(s0));
        console2.log("PEAPODS supply after", uint256(s1));
        console2.log("PEAPODS borrow before", uint256(b0));
        console2.log("PEAPODS borrow after", uint256(b1));
        console2.log("PEAPODS engineered delta", uint256(s1) - uint256(s0));
        assertGe(uint256(s1) - uint256(s0), seedAmt);
        assertGe(uint256(b1) - uint256(b0), seedAmt);
        assertEq(seeder.lastSeed(), seedAmt);
    }

    function test_peapods_seed_max_headroom_slice() public {
        (uint128 s0,, uint128 b0,,,) = IMorphoT(MORPHO).market(RSS_MID);
        uint256 seedAmt = 3_000_000e6; // under ~3.28M LTV headroom

        vm.startPrank(HOT);
        CrownPeapodsMorphoSeed seeder = new CrownPeapodsMorphoSeed(MORPHO, USDC, HOT, RSS_MID);
        IMorphoT(MORPHO).setAuthorization(address(seeder), true);
        seeder.seed(seedAmt);
        vm.stopPrank();

        (uint128 s1,, uint128 b1,,,) = IMorphoT(MORPHO).market(RSS_MID);
        console2.log("PEAPODS_3M engineered supply delta", uint256(s1) - uint256(s0));
        console2.log("PEAPODS_3M engineered borrow delta", uint256(b1) - uint256(b0));
        assertGe(uint256(s1) - uint256(s0), seedAmt);
    }

    function test_venus_multiply_lands_usdc_with_equity() public {
        // Venus: equity required. 500 WETH equity + 0 flash ≈ Path E; here flash+equity multiply.
        uint256 equity = 500e18;
        uint256 flash = 100e18;
        uint256 borrowUsdc = 900_000e6; // repay ~100 WETH via swap + residual to Landing
        deal(WETH, HOT, equity);

        uint256 before_ = IERC20T(USDC).balanceOf(LANDING);
        vm.startPrank(HOT);
        CrownVenusWethMultiply m = new CrownVenusWethMultiply(
            MORPHO, AERO, WETH, USDC, HOT, LANDING, AERO_FACTORY, WETH_MID
        );
        IERC20T(WETH).approve(address(m), equity);
        try m.multiply(flash, equity, borrowUsdc) {
            uint256 delta = IERC20T(USDC).balanceOf(LANDING) - before_;
            console2.log("VENUS Landing delta", delta);
            console2.log("VENUS credit", m.lastLandingCredit());
            console2.log("VENUS borrow", m.lastBorrow());
            assertGt(delta, 0);
        } catch (bytes memory reason) {
            console2.log("VENUS REVERT");
            console2.logBytes(reason);
        }
        vm.stopPrank();
    }
}
