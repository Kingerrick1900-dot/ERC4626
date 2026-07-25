// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownSpoilsFill} from "../src/CrownSpoilsFill.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorpho {
    function setAuthorization(address, bool) external;
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}

contract SpoilsFillForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant ORACLE_10 = 0x04aa048DCb46FC80e9Ebd0717612c9fFF834f385;
    bytes32 constant TEN = 0x96228d1eae39767dda3053b36301b220b74a78adca6ffac5ad6c8b155e51d7cc;

    function setUp() public {
        vm.createSelectFork(vm.envOr("RPC_URL", string("https://mainnet.base.org")), 49097059);
        vm.etch(HOT, hex"");
    }

    function test_fill_unlocks_700k_spoil_to_king() public {
        uint256 eleBal = IERC20(ELE).balanceOf(HOT);
        require(eleBal > 1e12, "need free ELE");

        vm.startPrank(HOT);
        CrownSpoilsFill rail = new CrownSpoilsFill(HOT, ORACLE_10);
        IMorpho(MORPHO).setAuthorization(address(rail), true);
        uint256 d = rail.debt();
        uint256 ask = d + 1e6;
        IERC20(ELE).approve(address(rail), eleBal);
        rail.list(eleBal, ask, false);
        vm.stopPrank();

        address filler = makeAddr("filler");
        deal(USDC, filler, ask, true);

        uint256 hot0 = IERC20(USDC).balanceOf(HOT);
        vm.startPrank(filler);
        IERC20(USDC).approve(address(rail), ask);
        rail.fill();
        vm.stopPrank();

        (, uint128 borAfter,) = IMorpho(MORPHO).position(TEN, HOT);
        (uint256 supAfter,,) = IMorpho(MORPHO).position(TEN, HOT);
        uint256 hot1 = IERC20(USDC).balanceOf(HOT);

        assertEq(uint256(borAfter), 0);
        assertEq(supAfter, 0);
        assertGe(hot1 - hot0, 500_000e6);
        assertGe(IERC20(ELE).balanceOf(filler), eleBal);
        console2.log("spoilDelta", hot1 - hot0);
        console2.log("fillerELE", IERC20(ELE).balanceOf(filler));
    }
}
