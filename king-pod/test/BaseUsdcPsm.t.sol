// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownBaseUsdcPsm} from "../src/CrownBaseUsdcPsm.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IEusdT {
    function owner() external view returns (address);
    function setMinter(address, bool) external;
    function mint(address, uint256) external;
    function isMinter(address) external view returns (bool);
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice Base Maker PSM fork: mint USDC→eUSD, redeem eUSD→USDC.
contract BaseUsdcPsmForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC", string("https://mainnet.base.org")));
    }

    function test_mint_and_redeem_one_to_one() public {
        CrownBaseUsdcPsm psm = new CrownBaseUsdcPsm(HOT, LAND, EUSD, USDC, 0);

        vm.prank(HOT);
        IEusdT(EUSD).setMinter(address(psm), true);
        assertTrue(IEusdT(EUSD).isMinter(address(psm)), "minter");

        uint256 usdcIn = 10_000e6;
        deal(USDC, HOT, usdcIn);

        uint256 supplyBefore = IEusdT(EUSD).totalSupply();
        vm.startPrank(HOT);
        IERC20T(USDC).approve(address(psm), usdcIn);
        uint256 minted = psm.mint(usdcIn, HOT);
        vm.stopPrank();

        assertEq(minted, 10_000e18, "mint 1:1");
        assertEq(IEusdT(EUSD).totalSupply() - supplyBefore, 10_000e18, "supply");
        assertEq(psm.usdcReserve(), usdcIn, "reserve grown");

        vm.startPrank(HOT);
        IEusdT(EUSD).approve(address(psm), minted);
        uint256 out = psm.redeem(minted, LAND);
        vm.stopPrank();

        assertEq(out, usdcIn, "redeem 1:1");
        assertEq(psm.usdcReserve(), 0, "reserve drained");
        assertEq(IERC20T(USDC).balanceOf(LAND) >= usdcIn, true, "land");
        assertEq(IEusdT(EUSD).totalSupply(), supplyBefore, "burned");
    }

    function test_redeem_reverts_when_dry() public {
        CrownBaseUsdcPsm psm = new CrownBaseUsdcPsm(HOT, LAND, EUSD, USDC, 0);
        vm.prank(HOT);
        IEusdT(EUSD).setMinter(address(psm), true);

        // Give HOT eUSD without USDC in PSM
        vm.prank(address(psm)); // can't — need a minter. Use WETH CDP or deal.
        deal(EUSD, HOT, 1e18);

        vm.startPrank(HOT);
        IEusdT(EUSD).approve(address(psm), 1e18);
        vm.expectRevert(CrownBaseUsdcPsm.Dry.selector);
        psm.redeem(1e18, HOT);
        vm.stopPrank();
    }

    function test_mint_fee_to_landing() public {
        CrownBaseUsdcPsm psm = new CrownBaseUsdcPsm(HOT, LAND, EUSD, USDC, 50); // 0.5%
        vm.prank(HOT);
        IEusdT(EUSD).setMinter(address(psm), true);

        deal(USDC, HOT, 10_000e6);
        uint256 landBefore = IERC20T(USDC).balanceOf(LAND);

        vm.startPrank(HOT);
        IERC20T(USDC).approve(address(psm), 10_000e6);
        uint256 got = psm.mint(10_000e6, HOT);
        vm.stopPrank();

        assertEq(got, 9950e18, "eusd net");
        assertEq(psm.usdcReserve(), 9950e6, "reserve net");
        assertEq(IERC20T(USDC).balanceOf(LAND) - landBefore, 50e6, "fee");
    }
}
