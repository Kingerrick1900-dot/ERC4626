// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownElepanPsm} from "../src/CrownElepanPsm.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

/// @notice Kingdom PSM: eUSD → USDC with seeded reserve (no external curator).
contract ElepanPsmForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    uint256 constant ASK = 700_000e6;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC", string("https://mainnet.base.org")));
    }

    function test_buyUsdc_clears_eusd_to_landing() public {
        CrownElepanPsm psm = new CrownElepanPsm(HOT, LAND, EUSD, USDC, 0);
        deal(USDC, address(psm), ASK);

        // Use king eUSD; top up on fork if book is thin.
        uint256 need = ASK * 1e12;
        uint256 have = IERC20T(EUSD).balanceOf(HOT);
        if (have < need) deal(EUSD, HOT, need);

        uint256 landBefore = IERC20T(USDC).balanceOf(LAND);
        vm.startPrank(HOT);
        IERC20T(EUSD).approve(address(psm), need);
        uint256 out = psm.buyUsdc(need, LAND);
        vm.stopPrank();

        console2.log("usdcOut", out);
        assertEq(out, ASK, "1:1");
        assertEq(IERC20T(USDC).balanceOf(LAND) - landBefore, ASK, "land");
        assertEq(IERC20T(EUSD).balanceOf(address(psm)), need, "sterilized");
    }

    function test_sellUsdc_grows_reserve() public {
        CrownElepanPsm psm = new CrownElepanPsm(HOT, LAND, EUSD, USDC, 50); // 0.5%
        uint256 eusdInv = 100_000e18;
        deal(EUSD, address(psm), eusdInv);
        deal(USDC, HOT, 10_000e6);

        vm.startPrank(HOT);
        IERC20T(USDC).approve(address(psm), 10_000e6);
        uint256 got = psm.sellUsdc(10_000e6, HOT);
        vm.stopPrank();

        // 0.5% fee → 9950 USDC notional → eUSD; fee to Landing
        assertEq(got, 9950e18, "eusd");
        (uint256 u,) = psm.reserves();
        assertEq(u, 9950e6, "reserve");
        assertEq(IERC20T(USDC).balanceOf(LAND) >= 50e6, true, "fee");
    }
}
