// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownKaminoMultiply} from "../src/CrownKaminoMultiply.sol";

interface IMorphoAuth {
    function setAuthorization(address, bool) external;
}

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice EXACT Kamino Multiply — Landing USDC must hit. No rematch cosplay.
contract KaminoMultiplyFork is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant AERO = 0xcDAC0d6c6C59727a65F871236188350531885C43; // WETH/USDC deep
    bytes32 constant MID = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;

    uint256 constant FLASH = 500_000e6; // smaller flash = less swap impact on Aero
    uint256 constant WANT = 700_000e6;
    uint256 constant EQUITY = 700 ether; // ~$1.33M @ ~$1903 — LTV headroom for flash+want+slip

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
    }

    function test_kamino_exact_landing_hits_700k() public {
        // Equity for exact Kamino (user deposit). Live: WETH from wrap / free-RSS bridge.
        deal(WETH, HOT, EQUITY);

        uint256 landBefore = IERC20T(USDC).balanceOf(LANDING);

        vm.startPrank(HOT);
        CrownKaminoMultiply k = new CrownKaminoMultiply(MORPHO, USDC, WETH, AERO, HOT, LANDING, MID);
        IMorphoAuth(MORPHO).setAuthorization(address(k), true);
        IERC20T(WETH).approve(address(k), EQUITY);

        // Exact Kamino: flash → swap USDC→WETH → supply → borrow → repay flash; want → Landing
        k.multiply(EQUITY, FLASH, WANT, 1); // minWethFromSwap dust floor; pool is deep
        vm.stopPrank();

        uint256 landAfter = IERC20T(USDC).balanceOf(LANDING);
        uint256 delta = landAfter - landBefore;

        console2.log("landingBefore", landBefore);
        console2.log("landingAfter", landAfter);
        console2.log("landingDelta", delta);
        console2.log("wethSupplied", k.lastWethSupplied());
        console2.log("borrowed", k.lastBorrowed());
        console2.log("closed", k.lastClosed());

        assertTrue(k.lastClosed());
        assertEq(k.lastLandingCredit(), WANT);
        assertEq(delta, WANT, "Landing USDC MUST hit 700k - Kamino law");
    }

    function test_kamino_refuses_when_landing_would_miss() public {
        // No equity → LTV cannot support flash+want → revert (never partial fire)
        vm.startPrank(HOT);
        CrownKaminoMultiply k = new CrownKaminoMultiply(MORPHO, USDC, WETH, AERO, HOT, LANDING, MID);
        IMorphoAuth(MORPHO).setAuthorization(address(k), true);
        vm.expectRevert();
        k.multiply(0, FLASH, WANT, 1);
        vm.stopPrank();
    }
}
