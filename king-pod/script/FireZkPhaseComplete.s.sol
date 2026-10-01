// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

/// @notice Orchestrate ZK phase: Elepan bind + settlement proof (Base) + Scroll micro-seed.
/// Base: KING_GO=1 FIRE_ZK=1 PRIVATE_KEY=… [already ran elepan+settlement via sub-scripts]
/// Scroll: KING_GO=1 FIRE_ZK=1 FIRE_MICRO_SCROLL=1 SCROLL_PRIVATE_KEY=… SCROLL_RPC=…
contract FireZkPhaseComplete is Script {
    address constant ELEPAN_GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    address constant SETTLE_GATE = 0x7c48a7fAA294C4b04002f65FA03F7C5ce952B637;
    address constant BOUND_GATE = 0xab2856626BBd8E6fba9dB93783029eB973E8427F;
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;

    function run() external view {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_ZK", uint256(0)) == 1, "NEED FIRE_ZK=1");
        console2.log("elepanGate", ELEPAN_GATE);
        console2.log("settleGate", SETTLE_GATE);
        console2.log("boundGate", BOUND_GATE);
        console2.log("hot", HOT);
        console2.log("Run:");
        console2.log("  FireZkElepanBindSubmit (Base)");
        console2.log("  FireZkSettlementSubmit (Base)");
        console2.log("  FireMicroSeedCapitalize FIRE_MICRO_SCROLL=1 (Scroll)");
    }
}
