// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {Groth16WalletVerifier} from "../src/zk/Groth16WalletVerifier.sol";
import {CrownZkWalletGate} from "../src/zk/CrownZkWalletGate.sol";
import {CrownZkCredit} from "../src/zk/CrownZkCredit.sol";

/// @notice Deploy wallet-bind verifier + gate + credit wired to wallet gate.
/// @dev KING_OK=1 FIRE_ZK_WALLET_DEPLOY=1
contract FireZkWalletBindDeploy is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_ZK_WALLET_DEPLOY", uint256(0)) == 1, "NO_FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);
        Groth16WalletVerifier v = new Groth16WalletVerifier();
        CrownZkWalletGate gate = new CrownZkWalletGate(address(v), HOT);
        CrownZkCredit credit = new CrownZkCredit(USDC, address(gate), HOT, LANDING, HOT);
        vm.stopBroadcast();

        console2.log("Groth16WalletVerifier", address(v));
        console2.log("CrownZkWalletGate", address(gate));
        console2.log("CrownZkCredit", address(credit));
        console2.log("minThreshold", gate.minThreshold());
    }
}
