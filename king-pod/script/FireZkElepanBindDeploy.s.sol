// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownZkWalletGate} from "../src/zk/CrownZkWalletGate.sol";
import {CrownZkCredit} from "../src/zk/CrownZkCredit.sol";

/// @notice Elepan ZK attestation: reuse live Groth16WalletVerifier, new gate + institutional credit rail.
/// @dev Circuit still wallet_reserves: map Elepan 8dp → rss_equiv = elepan * 1e10 (see prove-elepan.sh).
///      KING_GO=1 FIRE_ZK_ELEPAN_DEPLOY=1
contract FireZkElepanBindDeploy is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    // Proven RSS wallet-bind verifier (same circuit; Elepan mapped into rss leg)
    address constant VERIFIER = 0xbb3C589E7451087290B56578f19bf08C7b1Fc17B;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_ZK_ELEPAN_DEPLOY", uint256(0)) == 1, "NEED FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        address verifier = vm.envOr("VERIFIER", VERIFIER);

        vm.startBroadcast(pk);
        CrownZkWalletGate gate = new CrownZkWalletGate(verifier, HOT);
        // threshold already 700k in constructor default
        CrownZkCredit credit = new CrownZkCredit(USDC, address(gate), HOT, LANDING, HOT);
        vm.stopBroadcast();

        console2.log("Elepan Groth16WalletVerifier", verifier);
        console2.log("CrownZkElepanGate", address(gate));
        console2.log("CrownZkElepanCredit (private vault rail)", address(credit));
        console2.log("minThreshold", gate.minThreshold());
    }
}
