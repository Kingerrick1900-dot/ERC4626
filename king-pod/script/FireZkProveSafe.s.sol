// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {CrownZkWalletGate} from "../src/zk/CrownZkWalletGate.sol";

/// @notice FIRE_ZK_PROVE_SAFE=1 · ZK_SHIELD=1 · HOT_KEY — refresh Safe WalletGate attest.
contract FireZkProveSafe is Script {
    using stdJson for string;

    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant ZK_WALLET_GATE = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;

    function run() external {
        require(vm.envOr("FIRE_ZK_PROVE_SAFE", uint256(0)) == 1, "FIRE_ZK_PROVE_SAFE");
        require(vm.envOr("ZK_SHIELD", uint256(0)) == 1, "ZK_SHIELD");
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        string memory path = string.concat(vm.projectRoot(), "/zk/proofs/wallet_safe_proof_solidity.json");
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
        uint256[4] memory pub;
        pub[0] = raw.readUint(".publicSignals[0]");
        pub[1] = raw.readUint(".publicSignals[1]");
        pub[2] = raw.readUint(".publicSignals[2]");
        pub[3] = raw.readUint(".publicSignals[3]");
        require(pub[0] == 1, "OK");
        require(address(uint160(pub[3])) == SAFE, "BAD_SUBJECT");

        CrownZkWalletGate gate = CrownZkWalletGate(ZK_WALLET_GATE);
        vm.startBroadcast(pk);
        gate.submitProof(a, b, c, pub);
        vm.stopBroadcast();
        require(gate.isProven(SAFE), "SAFE_UNPROVEN");
        console2.log("isProvenSAFE", true);
    }
}
