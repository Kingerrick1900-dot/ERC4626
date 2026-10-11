// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {CrownZkWalletGate} from "../src/zk/CrownZkWalletGate.sol";

/// @notice FIRE_ZK_PROVE_LANDING=1 · ZK_SHIELD=1 · HOT_KEY
/// @dev Submit wallet-bind proof for Landing → isProven(LANDING)=true. No KING_CUSTODY_OK.
contract FireZkProveLanding is Script {
    using stdJson for string;

    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant ZK_WALLET_GATE = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;

    function run() external {
        require(vm.envOr("FIRE_ZK_PROVE_LANDING", uint256(0)) == 1, "FIRE_ZK_PROVE_LANDING");
        require(vm.envOr("ZK_SHIELD", uint256(0)) == 1, "ZK_SHIELD");
        require(vm.envOr("KING_CUSTODY_OK", uint256(0)) == 0, "NO_CUSTODY_BYPASS");

        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        string memory path = string.concat(
            vm.projectRoot(),
            vm.envOr("PROOF_JSON", string("/zk/proofs/wallet_landing_proof_solidity.json"))
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
        require(address(uint160(pub[3])) == LANDING, "BAD_SUBJECT");

        CrownZkWalletGate gate = CrownZkWalletGate(ZK_WALLET_GATE);

        vm.startBroadcast(pk);
        gate.submitProof(a, b, c, pub);
        vm.stopBroadcast();

        require(gate.isProven(LANDING), "LANDING_STILL_UNPROVEN");
        (uint256 thr, uint256 at, bool valid) = gate.attestations(LANDING);
        console2.log("isProvenLANDING", true);
        console2.log("threshold", thr);
        console2.log("provenAt", at);
        console2.log("valid", valid);
    }
}
