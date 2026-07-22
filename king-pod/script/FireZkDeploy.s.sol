// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {Groth16Verifier} from "../src/zk/Groth16Verifier.sol";
import {CrownZkReservesGate} from "../src/zk/CrownZkReservesGate.sol";
import {CrownZkCredit} from "../src/zk/CrownZkCredit.sol";

/// @notice Deploy ZK verifier + reserves gate + credit line on Base.
/// @dev KING_OK=1 FIRE_ZK_DEPLOY=1
contract FireZkDeploy is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_ZK_DEPLOY", uint256(0)) == 1, "NO_FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);
        Groth16Verifier v = new Groth16Verifier();
        CrownZkReservesGate gate = new CrownZkReservesGate(address(v), HOT);
        CrownZkCredit credit = new CrownZkCredit(USDC, address(gate), HOT, HOT);
        vm.stopBroadcast();

        console2.log("Groth16Verifier", address(v));
        console2.log("CrownZkReservesGate", address(gate));
        console2.log("CrownZkCredit", address(credit));
        console2.log("minThreshold", gate.minThreshold());
    }
}
