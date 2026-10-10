// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ZkShieldLaw} from "./ZkShieldLaw.sol";
import {HarvesterFees} from "../src/HarvesterFees.sol";

/// @notice FIRE_BUILD6B_HARVESTER_FEES=1 · ZK_SHIELD=1 · HOT_KEY
/// @dev Atomic Build 6b — deploys ONLY HarvesterFees. Crowns to Safe.
contract FireBuild6bHarvesterFees is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ZK_WALLET_GATE = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    address constant BASE_ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;

    function run() external {
        require(vm.envOr("FIRE_BUILD6B_HARVESTER_FEES", uint256(0)) == 1, "FIRE_BUILD6B_HARVESTER_FEES");
        ZkShieldLaw.requireFire(HOT);
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);
        HarvesterFees h = new HarvesterFees(USDC, ZK_WALLET_GATE, BASE_ATTEST, SAFE, HOT, HOT);
        h.transferOwnership(SAFE);
        vm.stopBroadcast();

        console2.log("HARVESTER_FEES", address(h));
        console2.log("HOT", h.hot());
    }
}
