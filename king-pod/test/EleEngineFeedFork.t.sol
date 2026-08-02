// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownElepanEngineFeed} from "../src/CrownElepanEngineFeed.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoT {
    function setAuthorization(address, bool) external;
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IZkT {
    function isProven(address) external view returns (bool);
}

contract EleEngineFeedForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    bytes32 constant MID = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC", string("https://mainnet.base.org")));
    }

    function test_engine_feed_50m() public {
        require(IZkT(GATE).isProven(HOT), "gate");
        uint256 ask = 50_000_000e6;
        uint256 landBefore = IERC20T(USDC).balanceOf(LAND);
        uint256 ele = IERC20T(ELE).balanceOf(HOT);
        require(ele > 90_000_000e8, "ele");

        vm.startPrank(HOT);
        CrownElepanEngineFeed feed = new CrownElepanEngineFeed(HOT, LAND);
        IMorphoT(MORPHO).setAuthorization(address(feed), true);
        IERC20T(ELE).approve(address(feed), type(uint256).max);
        IERC20T(USDC).approve(address(feed), type(uint256).max);
        feed.feed(ele, ask);
        vm.stopPrank();

        (, uint128 bor, uint128 coll) = IMorphoT(MORPHO).position(MID, HOT);
        (uint128 sa,, uint128 ba,,,) = IMorphoT(MORPHO).market(MID);
        uint256 landAfter = IERC20T(USDC).balanceOf(LAND);

        console2.log("coll", uint256(coll));
        console2.log("borShares", uint256(bor));
        console2.log("mktSup", uint256(sa));
        console2.log("mktBor", uint256(ba));
        console2.log("landDelta", landAfter - landBefore);

        assertGt(uint256(coll), 90_000_000e8, "coll");
        assertGt(uint256(bor), 0, "bor");
        assertGe(uint256(ba), ask, "engine");
        // Idle dust + hot wallet USDC should hit Landing
        assertGt(landAfter, landBefore, "land");
    }
}
