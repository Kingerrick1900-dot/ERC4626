// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ZkShieldLaw} from "./ZkShieldLaw.sol";
import {CrownKRT} from "../src/CrownKRT.sol";

/// @notice FIRE_BUILD3_CROWN_KRT=1 · ZK_SHIELD=1 · HOT_KEY
/// @dev Atomic Build 3 — deploys ONLY CrownKRT. Crowns to Safe.
contract FireBuild3CrownKRT is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant ZK_WALLET_GATE = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    address constant BASE_ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    address constant ORACLE = 0x95f552e81911e85c9BAb182c77AaFb719404655a;
    address constant SOVEREIGN_RAIL = 0x4ae38CD0d8A23347B13f88038BF9c1AB73639003;

    function run() external {
        require(vm.envOr("FIRE_BUILD3_CROWN_KRT", uint256(0)) == 1, "FIRE_BUILD3_CROWN_KRT");
        ZkShieldLaw.requireFire(HOT);
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);
        CrownKRT krt = new CrownKRT(ZK_WALLET_GATE, BASE_ATTEST, ORACLE, SOVEREIGN_RAIL, SAFE, HOT);
        krt.transferOwnership(SAFE);
        vm.stopBroadcast();

        console2.log("CROWN_KRT", address(krt));
    }
}
