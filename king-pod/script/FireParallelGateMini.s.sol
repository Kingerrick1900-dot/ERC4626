// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownGateV2} from "../src/CrownGateV2.sol";
import {IMorphoMarket} from "../src/interfaces/IMorphoMarket.sol";

interface IZkMini {
    function isProven(address subject) external view returns (bool);
}

/// @notice Mini parallel Gate: Safe is King at deploy, HOT operator — no acceptKingship, no jammed nonce.
/// @dev FIRE_PARALLEL_GATE_MINI=1 · ZK_SHIELD=1 · HOT_KEY
///      Same market 0x1bfd… (38.5% LLTV). Old Gate 0x8Bbd… left pending; this one is live.
contract FireParallelGateMini is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant SOV_ORACLE = 0x22E2F66a26eA8d01E0Bb4154ef4DfB0304a34f2d;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant ZK_WALLET_GATE = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    bytes32 constant PAR = 0x1bfd981b9905c55085390f7dedad00f32cd43527acf9dabe7de758e3f6c42134;
    uint256 constant PARALLEL_LLTV = 385000000000000000;

    function run() external {
        require(vm.envOr("FIRE_PARALLEL_GATE_MINI", uint256(0)) == 1, "FIRE_PARALLEL_GATE_MINI");
        require(vm.envOr("ZK_SHIELD", uint256(0)) == 1, "ZK_SHIELD_REQUIRED");

        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        require(IZkMini(ZK_WALLET_GATE).isProven(SAFE), "NOT_PROVEN_SAFE");

        IMorphoMarket.MarketParams memory mp =
            IMorphoMarket.MarketParams(USDC, RSS, SOV_ORACLE, IRM, PARALLEL_LLTV);
        require(keccak256(abi.encode(mp)) == PAR, "PAR_ID");

        vm.startBroadcast(pk);
        // Safe King + HOT operator at birth — skip Safe accept entirely.
        CrownGateV2 gate = new CrownGateV2(SAFE, ZK_WALLET_GATE, mp, HOT);
        vm.stopBroadcast();

        require(gate.king() == SAFE, "KING");
        require(gate.pendingKing() == address(0), "PENDING");
        require(gate.operator(HOT), "OP");
        require(gate.MARKET_ID() == PAR, "MARKET");

        console2.log("MINI_GATE", address(gate));
        console2.log("king", gate.king());
        console2.log("pendingKing", gate.pendingKing());
        console2.log("operatorHOT", gate.operator(HOT));
        console2.logBytes32(gate.MARKET_ID());
        console2.log("MISSION parallel mini Gate live - Safe King, no accept");
    }
}
