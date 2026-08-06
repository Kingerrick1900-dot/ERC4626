// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownLiFiSixStep} from "../src/CrownLiFiSixStep.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoT {
    function setAuthorization(address, bool) external;
}

/// @notice Find which 6-step variant puts USDC on Landing. Report honest deltas.
contract LiFiSixStepFork is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant BALANCER = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address constant RSS_ORACLE = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;
    address constant WETH_ORACLE = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    bytes32 constant RSS_MID = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    CrownLiFiSixStep m;

    function setUp() public {
        vm.prank(HOT);
        m = new CrownLiFiSixStep(
            MORPHO, BALANCER, USDC, WETH, RSS, HOT, LANDING, RSS_MID, RSS_ORACLE, WETH_ORACLE, IRM
        );
        vm.prank(HOT);
        IMorphoT(MORPHO).setAuthorization(address(m), true);
    }

    function test_A_supply_extract_landing() public {
        uint256 before_ = IERC20T(USDC).balanceOf(LANDING);
        uint256 flash = 700_000e6;
        vm.prank(HOT);
        try m.runSupplyExtract(flash) {
            uint256 delta = IERC20T(USDC).balanceOf(LANDING) - before_;
            console2.log("A SUPPLY_EXTRACT Landing delta", delta);
            console2.log("A credit", m.lastLandingCredit());
        } catch (bytes memory reason) {
            console2.log("A SUPPLY_EXTRACT REVERT");
            console2.logBytes(reason);
            console2.log("A Landing delta", IERC20T(USDC).balanceOf(LANDING) - before_);
        }
    }

    function test_B_rss_reborrow_landing_700k() public {
        uint256 before_ = IERC20T(USDC).balanceOf(LANDING);
        uint256 flash = 700_000e6;
        uint256 extraRss = 1_000_000e18; // free RSS on hot
        uint256 land = 700_000e6;
        vm.startPrank(HOT);
        IERC20T(RSS).approve(address(m), extraRss);
        try m.runRssReborrow(flash, extraRss, land) {
            uint256 delta = IERC20T(USDC).balanceOf(LANDING) - before_;
            console2.log("B RSS_REBORROW Landing delta", delta);
            console2.log("B credit", m.lastLandingCredit());
        } catch (bytes memory reason) {
            console2.log("B RSS_REBORROW REVERT");
            console2.logBytes(reason);
            console2.log("B Landing delta", IERC20T(USDC).balanceOf(LANDING) - before_);
        }
        vm.stopPrank();
    }

    function test_C_six_step_morpho_weth_flash() public {
        uint256 before_ = IERC20T(USDC).balanceOf(LANDING);
        // size WETH flash to Balancer-available-ish; Morpho has ~77k WETH
        uint256 usdcFlash = 700_000e6;
        uint256 wethFlash = 500e18;
        uint256 land = 700_000e6;
        vm.prank(HOT);
        try m.runSixStepMorpho(usdcFlash, wethFlash, land) {
            uint256 delta = IERC20T(USDC).balanceOf(LANDING) - before_;
            console2.log("C SIX_MORPHO Landing delta", delta);
            console2.log("C credit", m.lastLandingCredit());
        } catch (bytes memory reason) {
            console2.log("C SIX_MORPHO REVERT");
            console2.logBytes(reason);
            console2.log("C Landing delta", IERC20T(USDC).balanceOf(LANDING) - before_);
        }
    }

    function test_D_six_step_balancer_weth_flash() public {
        uint256 before_ = IERC20T(USDC).balanceOf(LANDING);
        uint256 balWeth = IERC20T(WETH).balanceOf(BALANCER);
        uint256 wethFlash = balWeth > 20e18 ? 20e18 : balWeth / 2;
        uint256 usdcFlash = 50_000e6; // balancer USDC thin — keep USDC flash on Morpho small relative
        uint256 land = 10_000e6;
        console2.log("D Balancer WETH available", balWeth);
        vm.prank(HOT);
        try m.runSixStepBalancer(usdcFlash, wethFlash, land) {
            uint256 delta = IERC20T(USDC).balanceOf(LANDING) - before_;
            console2.log("D SIX_BALANCER Landing delta", delta);
            console2.log("D credit", m.lastLandingCredit());
        } catch (bytes memory reason) {
            console2.log("D SIX_BALANCER REVERT");
            console2.logBytes(reason);
            console2.log("D Landing delta", IERC20T(USDC).balanceOf(LANDING) - before_);
        }
    }

    function test_E_rss_reborrow_flash_equals_idle_only() public {
        // borrow only flash amount (landing 0) — should settle if idle==flash
        uint256 before_ = IERC20T(USDC).balanceOf(LANDING);
        uint256 flash = 700_000e6;
        vm.startPrank(HOT);
        try m.runRssReborrow(flash, 0, 0) {
            console2.log("E REBORROW land0 delta", IERC20T(USDC).balanceOf(LANDING) - before_);
            console2.log("E mode", m.lastMode());
        } catch (bytes memory reason) {
            console2.log("E REVERT");
            console2.logBytes(reason);
        }
        vm.stopPrank();
    }
}
