// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownZkReservesGate} from "../src/zk/CrownZkReservesGate.sol";

/// @notice Submit Groth16 reserves proof to gate on Base.
/// @dev KING_OK=1 FIRE_ZK_PROOF=1 GATE=0x… 
///      Pass proof via env JSON path or inline:
///      PROOF_A0 PROOF_A1 PROOF_B00 PROOF_B01 PROOF_B10 PROOF_B11 PROOF_C0 PROOF_C1
///      PUB_OK PUB_THRESHOLD PUB_SUBJECT
///      Or: PROOF_JSON=king-pod/zk/proofs/proof_solidity.json (foundry can't read easily — use env ints)
contract FireZkSubmitProof is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_ZK_PROOF", uint256(0)) == 1, "NO_FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        address gateAddr = vm.envAddress("GATE");
        CrownZkReservesGate gate = CrownZkReservesGate(gateAddr);

        uint256[2] memory a;
        a[0] = vm.envUint("PROOF_A0");
        a[1] = vm.envUint("PROOF_A1");

        uint256[2][2] memory b;
        b[0][0] = vm.envUint("PROOF_B00");
        b[0][1] = vm.envUint("PROOF_B01");
        b[1][0] = vm.envUint("PROOF_B10");
        b[1][1] = vm.envUint("PROOF_B11");

        uint256[2] memory c;
        c[0] = vm.envUint("PROOF_C0");
        c[1] = vm.envUint("PROOF_C1");

        uint256[3] memory pub;
        pub[0] = vm.envUint("PUB_OK");
        pub[1] = vm.envUint("PUB_THRESHOLD");
        pub[2] = vm.envUint("PUB_SUBJECT");

        vm.startBroadcast(pk);
        gate.submitProof(a, b, c, pub);
        vm.stopBroadcast();

        console2.log("proven", gate.isProven(HOT));
        (uint256 thr, uint256 at, bool valid) = gate.attestations(HOT);
        console2.log("threshold", thr);
        console2.log("provenAt", at);
        console2.log("valid", valid);
    }
}
