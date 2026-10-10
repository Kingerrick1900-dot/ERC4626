// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownCircuitBreaker} from "../src/CrownCircuitBreaker.sol";
import {CrownAmoPauseStub} from "../src/CrownAmoPauseStub.sol";

/// @notice Register pause stubs for Sweep, Convert, Spoils, DeepPull under breaker.
contract FireAmo6RegisterMore is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant BRK = 0xd92482bb8a4Ac2F6B80cd1583D2b7AcB630759A8;

    function run() external {
        require(vm.envOr("FIRE_AMO6", uint256(0)) == 1, "FIRE_AMO6");
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        CrownCircuitBreaker brk = CrownCircuitBreaker(BRK);

        vm.startBroadcast(pk);
        // one stub per rail label via separate deploys
        for (uint256 i; i < 3; i++) {
            CrownAmoPauseStub stub = new CrownAmoPauseStub(HOT);
            brk.registerAMO(address(stub));
            console2.log("stub", address(stub));
        }
        console2.log("amoCount", brk.amoCount());
        vm.stopBroadcast();
    }
}
