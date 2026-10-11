// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ZkShieldLaw} from "./ZkShieldLaw.sol";
import {SovereignRailLLTV55} from "../src/SovereignRailLLTV55.sol";

/// @notice FIRE_BUILD1_SOVEREIGN_RAIL=1 · ZK_SHIELD=1 · HOT_KEY
/// @dev Atomic Build 1 — deploys ONLY SovereignRailLLTV55. Crowns to Safe.
contract FireBuild1SovereignRail is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant ZK_WALLET_GATE = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    address constant BASE_ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;

    function run() external {
        require(vm.envOr("FIRE_BUILD1_SOVEREIGN_RAIL", uint256(0)) == 1, "FIRE_BUILD1_SOVEREIGN_RAIL");
        ZkShieldLaw.requireFire(HOT);
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);
        SovereignRailLLTV55 rail = new SovereignRailLLTV55(ZK_WALLET_GATE, BASE_ATTEST, SAFE, HOT);
        rail.setLLTV(rail.DEFAULT_LLTV());
        rail.transferOwnership(SAFE);
        vm.stopBroadcast();

        console2.log("SOVEREIGN_RAIL_LLTV55", address(rail));
    }
}
