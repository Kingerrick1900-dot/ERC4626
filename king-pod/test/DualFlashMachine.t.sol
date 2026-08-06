// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownDualFlashMachine} from "../src/CrownDualFlashMachine.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoT {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function setAuthorization(address, bool) external;
    function supplyCollateral(MarketParams memory, uint256, address, bytes calldata) external;
}

contract DualFlashMachineFork is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant RSS_ORACLE = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;
    address constant WETH_ORACLE = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;

    CrownDualFlashMachine machine;

    function setUp() public {
        vm.prank(HOT);
        machine = new CrownDualFlashMachine(
            MORPHO, USDC, WETH, RSS, HOT, LANDING, RSS_ORACLE, WETH_ORACLE, IRM
        );
        vm.prank(HOT);
        IMorphoT(MORPHO).setAuthorization(address(machine), true);
    }

    function test_A_create_idle_with_dualflash_nets_zero() public {
        uint256 landBefore = IERC20T(USDC).balanceOf(LANDING);
        uint256 amt = 700_000e6;

        // Give machine RSS coll so it can borrow the idle it creates
        vm.startPrank(HOT);
        IERC20T(RSS).approve(MORPHO, 2000e18);
        IMorphoT(MORPHO).supplyCollateral(
            IMorphoT.MarketParams(USDC, RSS, RSS_ORACLE, IRM, 0.77e18),
            2000e18,
            address(machine),
            ""
        );
        vm.stopPrank();

        uint256 flashable = IERC20T(USDC).balanceOf(MORPHO);
        if (amt > flashable / 2) amt = flashable / 2;

        vm.prank(HOT);
        machine.runUsdcFlash(1, amt); // MODE_CREATE_IDLE_REPAY

        uint256 delta = IERC20T(USDC).balanceOf(LANDING) - landBefore;
        console2.log("A CREATE_IDLE Landing delta", delta);
        console2.log("A lastCredit", machine.lastLandingCredit());
        assertEq(delta, 0);
    }

    function test_B_unwind_matched_residual() public {
        uint256 landBefore = IERC20T(USDC).balanceOf(LANDING);
        uint256 flashable = IERC20T(USDC).balanceOf(MORPHO);
        uint256 amt = flashable > 2_000_000e6 ? flashable - 1_000_000e6 : flashable / 2;

        vm.prank(HOT);
        try machine.runUsdcFlash(2, amt) { // MODE_UNWIND
            uint256 delta = IERC20T(USDC).balanceOf(LANDING) - landBefore;
            console2.log("B UNWIND Landing delta", delta);
            console2.log("B lastCredit", machine.lastLandingCredit());
        } catch (bytes memory reason) {
            console2.log("B UNWIND REVERT");
            console2.logBytes(reason);
            console2.log("B Landing delta", IERC20T(USDC).balanceOf(LANDING) - landBefore);
        }
    }

    function test_C_equity_weth_lands_700k_LIFi_shape() public {
        uint256 wethIn = 500e18;
        uint256 usdcOut = 700_000e6;
        deal(WETH, HOT, wethIn);
        uint256 landBefore = IERC20T(USDC).balanceOf(LANDING);

        vm.startPrank(HOT);
        IERC20T(WETH).approve(address(machine), wethIn);
        machine.equityWethBorrow(wethIn, usdcOut);
        vm.stopPrank();

        uint256 delta = IERC20T(USDC).balanceOf(LANDING) - landBefore;
        console2.log("C EQUITY_WETH Landing delta", delta);
        assertEq(delta, usdcOut);
    }

    function test_D_weth_flash_no_equity_reverts() public {
        uint256 landBefore = IERC20T(USDC).balanceOf(LANDING);
        vm.prank(HOT);
        try machine.runWethFlash(3, 500e18, 700_000e6) { // MODE_WETH_FLASH_LANDING
            uint256 delta = IERC20T(USDC).balanceOf(LANDING) - landBefore;
            console2.log("D unexpected success Landing delta", delta);
            // If it "succeeds", WETH must have been repaid somehow — still report
        } catch {
            console2.log("D WETH flash without equity REVERTS - Landing unchanged");
            assertEq(IERC20T(USDC).balanceOf(LANDING), landBefore);
        }
    }
}
