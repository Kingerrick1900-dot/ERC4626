// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownOpsFive} from "../src/CrownOpsFive.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoT {
    function setAuthorization(address, bool) external;
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}

interface IYeleT {
    function setIsAllocator(address, bool) external;
    function totalAssets() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function maxWithdraw(address) external view returns (uint256);
}

interface IZkT {
    function isProven(address) external view returns (bool);
}

/// @dev Fork: flash-repay ELE debt → yELE withdraw → free coll. No WETH cap.
contract EleCleanseRedeemForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC", string("https://mainnet.base.org")));
    }

    function test_cleanse_ele_redeem() public {
        require(IZkT(GATE).isProven(HOT), "gate");

        uint256 eleBefore = IERC20T(ELE).balanceOf(HOT);
        uint256 landBefore = IERC20T(USDC).balanceOf(LAND);
        (, uint128 borBefore, uint128 collBefore) = IMorphoT(MORPHO).position(ELE_USDC, HOT);
        require(borBefore > 0 && collBefore > 0, "no position");

        vm.startPrank(HOT);
        CrownOpsFive ops = new CrownOpsFive(HOT, LAND);
        IMorphoT(MORPHO).setAuthorization(address(ops), true);
        IYeleT(YELE).setIsAllocator(address(ops), true);
        IERC20T(YELE).approve(address(ops), type(uint256).max);
        IERC20T(USDC).approve(address(ops), type(uint256).max);
        ops.cleanseEleRedeem();
        vm.stopPrank();

        (, uint128 borAfter, uint128 collAfter) = IMorphoT(MORPHO).position(ELE_USDC, HOT);
        uint256 eleAfter = IERC20T(ELE).balanceOf(HOT);
        uint256 landAfter = IERC20T(USDC).balanceOf(LAND);

        console2.log("debtAfter", uint256(borAfter));
        console2.log("collAfter", uint256(collAfter));
        console2.log("eleFreed", eleAfter - eleBefore);
        console2.log("landUsdcDelta", landAfter > landBefore ? landAfter - landBefore : 0);
        console2.log("yeleTA", IYeleT(YELE).totalAssets());
        console2.log("yeleSharesHot", IYeleT(YELE).balanceOf(HOT));
        console2.log("yeleMaxW", IYeleT(YELE).maxWithdraw(HOT));

        assertEq(uint256(borAfter), 0, "debt");
        assertEq(uint256(collAfter), 0, "coll");
        assertGe(eleAfter - eleBefore, uint256(collBefore), "ele");
    }
}
