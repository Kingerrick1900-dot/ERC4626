// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownLandingUsdcFacility} from "../src/CrownLandingUsdcFacility.sol";
import {CrownRssUsdcDesk} from "../src/CrownRssUsdcDesk.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IPsmT {
    function seed(address, uint256) external;
    function usdcReserve() external view returns (uint256);
}

contract LandingUsdcFacilityFork is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant PSM = 0xF7337A26d9456e42a36531A12036A4556EF1F987;
    address constant ORACLE = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;

    CrownLandingUsdcFacility fac;
    address funder = address(0xBEEF);

    function setUp() public {
        vm.prank(HOT);
        fac = new CrownLandingUsdcFacility(USDC, EUSD, RSS, PSM, HOT, LANDING);
    }

    function test_railA_otc_eusd_lands_700k() public {
        uint256 usdcOut = 700_000e6;
        uint256 eusdOut = 700_000e18;
        deal(USDC, funder, usdcOut);

        vm.prank(LANDING);
        IERC20T(EUSD).transfer(HOT, eusdOut);

        vm.startPrank(funder);
        IERC20T(USDC).approve(address(fac), usdcOut);
        fac.fundOtc(usdcOut);
        vm.stopPrank();

        uint256 before_ = IERC20T(USDC).balanceOf(LANDING);
        vm.startPrank(HOT);
        IERC20T(EUSD).approve(address(fac), eusdOut);
        fac.settleOtcEusd(usdcOut, eusdOut);
        vm.stopPrank();

        uint256 delta = IERC20T(USDC).balanceOf(LANDING) - before_;
        console2.log("RAIL_A OTC_EUSD Landing delta", delta);
        assertEq(delta, usdcOut);
    }

    function test_railB_rss_desk_lands_700k() public {
        uint256 usdcOut = 700_000e6;
        uint256 rssIn = 1_000e18;
        deal(USDC, funder, usdcOut);

        vm.prank(HOT);
        CrownRssUsdcDesk desk = new CrownRssUsdcDesk(RSS, USDC, ORACLE, HOT, LANDING, 0.75e18);

        vm.startPrank(funder);
        IERC20T(USDC).approve(address(fac), usdcOut);
        fac.fundDesk(address(desk), usdcOut);
        vm.stopPrank();

        uint256 before_ = IERC20T(USDC).balanceOf(LANDING);
        vm.startPrank(HOT);
        IERC20T(RSS).approve(address(desk), rssIn);
        desk.draw(rssIn, usdcOut, LANDING);
        vm.stopPrank();

        uint256 delta = IERC20T(USDC).balanceOf(LANDING) - before_;
        console2.log("RAIL_B RSS_DESK Landing delta", delta);
        assertEq(delta, usdcOut);
    }

    function test_railC_psm_buffer_and_seed() public {
        uint256 usdcSeed = 700_000e6;
        deal(USDC, funder, usdcSeed);

        vm.startPrank(funder);
        IERC20T(USDC).approve(address(fac), usdcSeed);
        fac.fundPsmBuffer(usdcSeed);
        vm.stopPrank();

        vm.startPrank(HOT);
        fac.pullPsmBuffer(usdcSeed);
        IERC20T(USDC).approve(PSM, usdcSeed);
        IPsmT(PSM).seed(USDC, usdcSeed);
        vm.stopPrank();

        console2.log("RAIL_C PSM seeded reserve", IPsmT(PSM).usdcReserve());
        assertEq(IPsmT(PSM).usdcReserve(), usdcSeed);
        // redeemAsset ABI on live MultiPSM reverts Dry/BadAmt — settle via Rail A/B until redeem path confirmed
    }
}

// quick probe appended in separate file
