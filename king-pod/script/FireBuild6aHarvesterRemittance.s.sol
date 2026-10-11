// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ZkShieldLaw} from "./ZkShieldLaw.sol";
import {HarvesterRemittance} from "../src/HarvesterRemittance.sol";

/// @notice FIRE_BUILD6A_HARVESTER_REMIT=1 · ZK_SHIELD=1 · HOT_KEY
/// @dev Atomic Build 6a — deploys ONLY HarvesterRemittance. Crowns to Safe.
contract FireBuild6aHarvesterRemittance is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ZK_WALLET_GATE = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    address constant BASE_ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    address constant KRT = 0xe8a40d2E62588102dbD61e0afA86f9BABE402A98;
    address constant NIGERIA_DESK = 0x4987b70136c5C4071900C6404b3b47C34142a234;
    address constant SOVEREIGN_RAIL = 0x4ae38CD0d8A23347B13f88038BF9c1AB73639003;

    function run() external {
        require(vm.envOr("FIRE_BUILD6A_HARVESTER_REMIT", uint256(0)) == 1, "FIRE_BUILD6A_HARVESTER_REMIT");
        ZkShieldLaw.requireFire(HOT);
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);
        HarvesterRemittance h = new HarvesterRemittance(
            USDC, ZK_WALLET_GATE, BASE_ATTEST, SAFE, HOT, KRT, NIGERIA_DESK, SOVEREIGN_RAIL, HOT
        );
        h.transferOwnership(SAFE);
        vm.stopBroadcast();

        console2.log("HARVESTER_REMITTANCE", address(h));
        console2.log("FEE_BPS", h.FEE_BPS());
        console2.log("NIGERIA_DESK", h.nigeriaDesk());
        console2.log("HOT", h.hot());
    }
}
