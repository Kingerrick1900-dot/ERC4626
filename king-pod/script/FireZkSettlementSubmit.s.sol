// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {CrownZkSettlementGate} from "../src/zk/CrownZkSettlementGate.sol";

/// @notice Submit settlement ZK proof to live gate. Proof: zk/proofs/settlement_proof_solidity.json
/// KING_GO=1 FIRE_ZK_SETTLEMENT=1 GATE=0x7c48a7fA…
contract FireZkSettlementSubmit is Script {
    using stdJson for string;

    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_ZK_SETTLEMENT", uint256(0)) == 1, "NEED FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        address gateAddr = vm.envAddress("GATE");
        string memory path = string.concat(vm.projectRoot(), "/zk/proofs/settlement_proof_solidity.json");
        string memory raw = vm.readFile(path);

        uint256[2] memory a;
        a[0] = raw.readUint(".a[0]");
        a[1] = raw.readUint(".a[1]");

        uint256[2][2] memory b;
        b[0][0] = raw.readUint(".b[0][0]");
        b[0][1] = raw.readUint(".b[0][1]");
        b[1][0] = raw.readUint(".b[1][0]");
        b[1][1] = raw.readUint(".b[1][1]");

        uint256[2] memory c;
        c[0] = raw.readUint(".c[0]");
        c[1] = raw.readUint(".c[1]");

        uint256[5] memory pub;
        for (uint256 i; i < 5; ++i) {
            pub[i] = raw.readUint(string.concat(".publicSignals[", vm.toString(i), "]"));
        }

        require(pub[0] == 1, "OK_NOT_1");
        require(address(uint160(pub[4])) == HOT, "BAD_SUBJECT");

        bytes32 orderId = bytes32(pub[2]);
        CrownZkSettlementGate gate = CrownZkSettlementGate(gateAddr);

        vm.startBroadcast(pk);
        gate.submitProof(a, b, c, pub);
        vm.stopBroadcast();

        console2.log("canFill", gate.canFill(orderId, HOT, pub[3]));
        console2.log("SETTLEMENT_ZK_LIVE", uint256(1));
    }
}
