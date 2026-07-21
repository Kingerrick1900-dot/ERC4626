// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownCollateralMachine} from "../src/CrownCollateralMachine.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IPoolT {
    function getReserves() external view returns (uint256, uint256, uint256);
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);
    function sync() external;
}

interface IMorphoAuthT {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
}

/// @dev Fork Base: 500k machine + cold-or-revert law.
contract CrownCollateralMachineForkTest is Test {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant AERO = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant AERO_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ADV = 0xD36ad3bf4E4A619f5b8F8C22DDA90E313F23035B;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant RSS_USDC_POOL = 0x2C4F14744B8b3D087b768D0764d983Acb46d537a;
    bytes32 constant MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    uint256 constant LLTV = 770000000000000000;
    uint256 constant AMT_500K = 500_000e6;

    CrownCollateralMachine machine;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC"));
        machine = new CrownCollateralMachine(
            MORPHO,
            AERO,
            AERO_FACTORY,
            USDC,
            RSS,
            ADV,
            LANDING,
            HOT,
            MARKET_ID,
            ORACLE,
            IRM,
            LLTV,
            address(this)
        );
    }

    function test_fork_borrow_500k_reverts_no_idle() public {
        vm.startPrank(HOT);
        IERC20T(RSS).approve(address(machine), 700_000 ether);
        IMorphoAuthT(MORPHO).setAuthorization(address(machine), true);
        vm.stopPrank();
        vm.expectRevert(CrownCollateralMachine.NoIdle.selector);
        machine.borrowToLanding(700_000 ether, AMT_500K);
    }

    function test_fork_flash_advance_500k_reverts_without_cold_depth() public {
        uint256 out = IPoolT(RSS_USDC_POOL).getAmountOut(500_000 ether, RSS);
        console2.log("livePoolUsdcOutFor500kRss", out);
        assertLt(out, AMT_500K, "pool unexpectedly deep");

        vm.prank(HOT);
        IERC20T(RSS).approve(address(machine), 500_000 ether);

        uint256 landBefore = IERC20T(USDC).balanceOf(LANDING);
        vm.expectRevert();
        machine.flashAdvanceToLanding(AMT_500K, 500_000 ether, AMT_500K);
        // LAW: failed path leaves cold unchanged
        assertEq(IERC20T(USDC).balanceOf(LANDING), landBefore, "cold moved on revert");
    }

    /// Seed deep pool on fork → Landing +500k or revert. Success path.
    function test_fork_flash_advance_500k_hits_cold() public {
        // $20M USDC + 2M RSS reserves so 600k RSS sale covers 500k flash repay
        deal(USDC, RSS_USDC_POOL, 20_000_000e6);
        deal(RSS, RSS_USDC_POOL, 2_000_000 ether);
        IPoolT(RSS_USDC_POOL).sync();

        uint256 quote = IPoolT(RSS_USDC_POOL).getAmountOut(600_000 ether, RSS);
        console2.log("seededQuote600kRss", quote);
        assertGe(quote, AMT_500K, "seed failed");

        vm.prank(HOT);
        IERC20T(RSS).approve(address(machine), 600_000 ether);

        uint256 landBefore = IERC20T(USDC).balanceOf(LANDING);
        machine.flashAdvanceToLanding(AMT_500K, 600_000 ether, AMT_500K);
        uint256 landAfter = IERC20T(USDC).balanceOf(LANDING);

        assertEq(landAfter - landBefore, AMT_500K, "LandingMiss");
        console2.log("COLD_HIT_500K", landAfter - landBefore);
    }

    function test_rescue_usdc_only_to_cold() public {
        uint256 landBefore = IERC20T(USDC).balanceOf(LANDING);
        deal(USDC, address(machine), 100e6);
        machine.rescue(USDC, HOT, 100e6); // to= ignored for USDC
        assertEq(IERC20T(USDC).balanceOf(address(machine)), 0);
        assertEq(IERC20T(USDC).balanceOf(LANDING) - landBefore, 100e6);
    }
}
