// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownGateV2} from "../src/CrownGateV2.sol";

/// @notice Rotate CrownGateV2 king HOT → new cold. HOT stays gate operator.
/// @dev FIRE_KING_ROTATE=1 · PHASE=initiate|accept|full (default full)
///      HOT_KEY → initiate · COLD_PRIVATE_KEY (or LANDING_PRIVATE_KEY) → accept + setOperator(HOT)
///      Optional COLD_ADDRESS env overrides default new cold.
contract FireKingRotate is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant DEFAULT_COLD = 0x5E07D7167282F9ec912a05c3048D7D0F24A8b826;
    address constant GATE = 0x76fa390951fA31185490378F46B6e9F05bA4bC3b;

    function run() external {
        require(vm.envOr("FIRE_KING_ROTATE", uint256(0)) == 1, "FIRE_KING_ROTATE");
        address cold = vm.envOr("COLD_ADDRESS", DEFAULT_COLD);
        string memory phase = vm.envOr("PHASE", string("full"));
        bytes32 p = keccak256(bytes(phase));

        if (p == keccak256("initiate") || p == keccak256("full")) {
            uint256 hotPk = vm.envUint("HOT_KEY");
            require(vm.addr(hotPk) == HOT, "NOT_HOT");
            console2.log("cold", cold);
            console2.log("gateKingBefore", CrownGateV2(GATE).king());
            console2.log("pendingBefore", CrownGateV2(GATE).pendingKing());
            vm.startBroadcast(hotPk);
            CrownGateV2(GATE).initiateKingTransfer(cold);
            vm.stopBroadcast();
            console2.log("pendingAfter", CrownGateV2(GATE).pendingKing());
            console2.log("KING_ROTATE_INITIATED", uint256(1));
        }

        if (p == keccak256("accept") || p == keccak256("full")) {
            uint256 coldPk = vm.envOr("COLD_PRIVATE_KEY", uint256(0));
            if (coldPk == 0) coldPk = vm.envUint("LANDING_PRIVATE_KEY");
            require(vm.addr(coldPk) == cold, "NOT_COLD");
            require(CrownGateV2(GATE).pendingKing() == cold, "PENDING_NOT_COLD");
            vm.startBroadcast(coldPk);
            CrownGateV2(GATE).acceptKingship();
            CrownGateV2(GATE).setOperator(HOT, true);
            vm.stopBroadcast();
            console2.log("gateKingAfter", CrownGateV2(GATE).king());
            console2.log("hotOperator", CrownGateV2(GATE).operator(HOT));
            console2.log("KING_ROTATE_COMPLETE", uint256(1));
        }
    }
}
