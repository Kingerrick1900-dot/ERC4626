// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownZeroMorpho} from "../src/CrownZeroMorpho.sol";

interface IMorphoAuth {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface IYrssA {
    function approve(address, uint256) external returns (bool);
}

interface IERC20A {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

contract ZeroLegacyMorphoTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ORACLE = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant LEGACY = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
    }

    function test_zero_legacy_252k_market() public {
        vm.startPrank(HOT);
        CrownZeroMorpho z = new CrownZeroMorpho(MORPHO, USDC, RSS, YRSS, HOT, LEGACY, ORACLE, IRM, LLTV, HOT);
        IMorphoAuth(MORPHO).setAuthorization(address(z), true);
        IYrssA(YRSS).approve(address(z), type(uint256).max);
        IERC20A(USDC).approve(address(z), type(uint256).max);
        z.zeroBooks();
        vm.stopPrank();
        (, uint128 bor, uint128 coll) = IMorphoAuth(MORPHO).position(LEGACY, HOT);
        console2.log("bor", bor);
        console2.log("coll", coll);
        console2.log("hotRss", IERC20A(RSS).balanceOf(HOT) / 1e18);
        assertEq(bor, 0);
        assertEq(coll, 0);
    }
}
