// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {CrownZkWalletGate} from "../src/zk/CrownZkWalletGate.sol";

/// @notice FIRE_ZK_WALLET_REFRESH=1 · ZK_SHIELD=1 · HOT_KEY
/// @dev Re-submit stored HOT wallet-bind proof to WalletGate — clears STALE_VALID.
contract FireZkWalletRefresh is Script {
    using stdJson for string;

    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant ZK_WALLET_GATE = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;

    function run() external {
        require(vm.envOr("FIRE_ZK_WALLET_REFRESH", uint256(0)) == 1, "FIRE_ZK_WALLET_REFRESH");
        require(vm.envOr("ZK_SHIELD", uint256(0)) == 1, "ZK_SHIELD");
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        address gateAddr = vm.envOr("ZK_WALLET_GATE", ZK_WALLET_GATE);
        string memory path = string.concat(
            vm.projectRoot(),
            vm.envOr("PROOF_JSON", string("/zk/proofs/wallet_proof_solidity.json"))
        );
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

        require(pub[0] == 1, "OK_NOT_1");
        require(address(uint160(pub[3])) == HOT, "BAD_SUBJECT");

        CrownZkWalletGate gate = CrownZkWalletGate(gateAddr);

        vm.startBroadcast(pk);
        gate.submitProof(a, b, c, pub);
        vm.stopBroadcast();

        require(gate.isProven(HOT), "HOT_STILL_UNPROVEN");
        (uint256 thr, uint256 at, bool valid) = gate.attestations(HOT);
        console2.log("isProvenHOT", true);
        console2.log("threshold", thr);
        console2.log("provenAt", at);
        console2.log("valid", valid);
        console2.log("MISSION HOT WalletGate refreshed - STALE cleared");
    }
}
