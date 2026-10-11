// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownCircuitBreaker} from "../src/CrownCircuitBreaker.sol";
import {CrownAmoPauseStub} from "../src/CrownAmoPauseStub.sol";

/// @notice Post-deploy arm: deploy pause stub, register on breaker. FIRE_AMO6=1.
contract FireAmo6Arm is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;

    function run() external {
        require(vm.envOr("FIRE_AMO6", uint256(0)) == 1, "FIRE_AMO6");
        address brkAddr = vm.envAddress("BREAKER");
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        CrownCircuitBreaker brk = CrownCircuitBreaker(brkAddr);

        vm.startBroadcast(pk);
        CrownAmoPauseStub stub = new CrownAmoPauseStub(HOT);
        brk.registerAMO(address(stub));
        console2.log("PauseStub", address(stub));
        console2.log("amoCount", brk.amoCount());
        console2.log("armed", brk.armed());
        console2.log("tripped", brk.tripped());
        console2.log("baseline", brk.yRssBaseline());
        vm.stopBroadcast();
        console2.log("MISSION AMO6 armed with pausable AMO");
    }
}
