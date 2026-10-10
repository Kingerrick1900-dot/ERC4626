// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownKingsCombinedFire} from "../src/zk/CrownKingsCombinedFire.sol";
import {CrownZkYieldLadder} from "../src/CrownZkYieldLadder.sol";
import {CrownGateV2} from "../src/CrownGateV2.sol";

interface IZkT {
    function isProven(address) external view returns (bool);
}

interface IMorphoT {
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

contract SimKingsCombined is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ZK = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    address constant GATE = 0x76fa390951fA31185490378F46B6e9F05bA4bC3b;
    address constant STEAK = 0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183;
    address constant GAUNTLET = 0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61;
    bytes32 constant SOV = 0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC_URL", vm.envOr("BASE_RPC", string(""))));
    }

    function test_secure_and_fire_matched_2m() public {
        assertTrue(IZkT(ZK).isProven(HOT));
        (, uint128 borBefore, uint128 coll) = IMorphoT(MORPHO).position(SOV, GATE);
        assertGt(uint256(coll), 0);

        vm.startPrank(HOT);
        CrownKingsCombinedFire fire =
            new CrownKingsCombinedFire(MORPHO, USDC, ZK, GATE, HOT, HOT, HOT);
        CrownGateV2(GATE).setOperator(address(fire), true);
        fire.fireMatched();
        vm.stopPrank();

        (, uint128 borAfter,) = IMorphoT(MORPHO).position(SOV, GATE);
        (uint256 engShares,,) = IMorphoT(MORPHO).position(SOV, address(fire));
        assertGt(uint256(borAfter), uint256(borBefore), "new debt");
        assertGt(engShares, 0, "engine LP");
        console2.log("borBefore", uint256(borBefore));
        console2.log("borAfter", uint256(borAfter));
        console2.log("engineLp", engShares);
        console2.log("KINGS_COMBINED_MATCHED", uint256(1));
    }

    function test_fire_with_cover_engine_and_reserve() public {
        deal(USDC, HOT, 2_000_000e6);
        uint256 hotBefore = IERC20T(USDC).balanceOf(HOT);

        vm.startPrank(HOT);
        CrownKingsCombinedFire fire =
            new CrownKingsCombinedFire(MORPHO, USDC, ZK, GATE, HOT, HOT, HOT);
        CrownZkYieldLadder ladder = new CrownZkYieldLadder(USDC, HOT, HOT, HOT);
        ladder.addRung(STEAK, 6000);
        ladder.addRung(GAUNTLET, 4000);
        fire.setLadder(address(ladder));
        CrownGateV2(GATE).setOperator(address(fire), true);
        IERC20T(USDC).approve(address(fire), type(uint256).max);
        fire.fireWithCover();
        ladder.allocateIdle();
        vm.stopPrank();

        // HOT paid 2M cover, received 1M reserve → net -1M; ladder holds engine
        assertEq(IERC20T(USDC).balanceOf(HOT), hotBefore - 1_000_000e6);
        assertGe(ladder.rungAssets(0) + ladder.rungAssets(1), 900_000e6);
        console2.log("ladderR0", ladder.rungAssets(0));
        console2.log("ladderR1", ladder.rungAssets(1));
        console2.log("KINGS_COMBINED_COVER", uint256(1));
    }
}
