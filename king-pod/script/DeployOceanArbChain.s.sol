// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {OceanArb} from "../src/OceanArb.sol";

/// @notice Deploy OceanArb on Polygon or Scroll. DEPLOY_OCEAN=1 · PRIVATE_KEY · USDC · KING · COLD · GATE · BUDGET
/// @dev Same bytecode as Base. Keeper points at each chain's OceanArb.
contract DeployOceanArbChain is Script {
    function run() external {
        require(vm.envOr("DEPLOY_OCEAN", uint256(0)) == 1, "DEPLOY_OCEAN");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address usdc = vm.envAddress("USDC");
        address king = vm.envAddress("KING");
        address cold = vm.envAddress("COLD");
        address gate = vm.envOr("GATE", address(0));
        uint256 budget = vm.envOr("BUDGET", uint256(3_000_000e6));

        vm.startBroadcast(pk);
        OceanArb ocean = new OceanArb(usdc, king, vm.addr(pk), budget);
        ocean.setColdBuffer(cold);
        if (gate != address(0)) ocean.setGate(gate);
        ocean.setMinEdgeBps(20);
        vm.stopBroadcast();

        console2.log("OCEAN_ARB", address(ocean));
        console2.log("CHAINID", block.chainid);
        console2.log("BUDGET", budget);
        console2.log("COLD", cold);
    }
}
