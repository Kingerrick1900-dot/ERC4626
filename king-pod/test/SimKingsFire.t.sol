// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownKingsFire} from "../src/zk/CrownKingsFire.sol";
import {CrownGateV2} from "../src/CrownGateV2.sol";

interface IZkT {
    function isProven(address) external view returns (bool);
}

interface IMorphoT {
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface ICreditT {
    function setOperator(address, bool) external;
    function debtOf(address) external view returns (uint256);
}

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

contract SimKingsFire is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ZK = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    address constant GATE = 0x76fa390951fA31185490378F46B6e9F05bA4bC3b;
    address constant CREDIT = 0x75279D46F0dA7f91D5283687C1D0a6EF86992e09;
    bytes32 constant SOV = 0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC_URL", vm.envOr("BASE_RPC", string(""))));
    }

    function test_fire_matched_1m_100k_zk() public {
        assertTrue(IZkT(ZK).isProven(HOT));
        vm.startPrank(HOT);
        CrownKingsFire fire = new CrownKingsFire(MORPHO, USDC, ZK, GATE, CREDIT, HOT, HOT, HOT);
        CrownGateV2(GATE).setOperator(address(fire), true);
        ICreditT(CREDIT).setOperator(address(fire), true);
        fire.fireMatched();
        vm.stopPrank();

        (, uint128 gBor,) = IMorphoT(MORPHO).position(SOV, GATE);
        assertGt(uint256(gBor), 0, "1M morpho debt");
        // prior port dust debt (~10278) may already sit on HOT
        assertGe(ICreditT(CREDIT).debtOf(HOT), 100_000e6, "credit debt at least 100k");
        console2.log("gateBorShares", uint256(gBor));
        console2.log("creditDebt", ICreditT(CREDIT).debtOf(HOT));
        console2.log("KINGS_FIRE_MATCHED", uint256(1));
    }

    function test_fire_with_cover_lands_on_hot() public {
        uint256 debtBefore = ICreditT(CREDIT).debtOf(HOT);
        deal(USDC, HOT, 1_100_000e6);
        uint256 before = IERC20T(USDC).balanceOf(HOT);
        vm.startPrank(HOT);
        CrownKingsFire fire = new CrownKingsFire(MORPHO, USDC, ZK, GATE, CREDIT, HOT, HOT, HOT);
        CrownGateV2(GATE).setOperator(address(fire), true);
        ICreditT(CREDIT).setOperator(address(fire), true);
        IERC20T(USDC).approve(address(fire), type(uint256).max);
        fire.fireWithCover();
        vm.stopPrank();
        // HOT paid 1.1M cover, received 1.1M draws → flat; debts live on gate/credit(HOT)
        assertEq(IERC20T(USDC).balanceOf(HOT), before);
        (, uint128 gBor,) = IMorphoT(MORPHO).position(SOV, GATE);
        assertGt(uint256(gBor), 0);
        assertEq(ICreditT(CREDIT).debtOf(HOT), debtBefore + 100_000e6);
        console2.log("KINGS_FIRE_COVER", uint256(1));
    }
}
