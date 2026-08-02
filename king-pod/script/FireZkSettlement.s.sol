// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {Groth16SettlementVerifier} from "../src/zk/Groth16SettlementVerifier.sol";
import {CrownZkSettlementGate} from "../src/zk/CrownZkSettlementGate.sol";

/// @notice Deploy settlement ZK verifier + gate on Base. Leaves 7540/7683 untouched.
/// KING_GO=1 forge script script/FireZkSettlement.s.sol:FireZkSettlement \
///   --rpc-url $BASE_RPC_URL --broadcast --slow
contract FireZkSettlement is Script {
    address constant BASE_HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == BASE_HOT, "BASE_HOT");

        vm.startBroadcast(pk);
        Groth16SettlementVerifier ver = new Groth16SettlementVerifier();
        CrownZkSettlementGate gate = new CrownZkSettlementGate(address(ver), BASE_HOT);
        console2.log("SETTLEMENT_VERIFIER", address(ver));
        console2.log("SETTLEMENT_GATE", address(gate));
        console2.log("minFillUsdc", gate.minFillUsdc());
        console2.log("proofTtl", gate.proofTtl());
        vm.stopBroadcast();
        console2.log("ZK_SETTLEMENT_OK", uint256(1));
    }
}
