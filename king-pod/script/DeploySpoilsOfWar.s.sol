// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownSpoilsOfWar} from "../src/CrownSpoilsOfWar.sol";

/// @notice Deploy end-state spoils router. Gate: FIRE_SPOILS=1 (after AMO6 green).
contract DeploySpoilsOfWar is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant COLD = 0xBb3c14bBacD639797cB5c537fde370d1b7195521;
    address constant OCEAN_DEFAULT = 0xDDe33827dbd0aC5Ed1a8A68eE5D95c829902679A; // DeepPull — first external leg

    function run() external {
        require(vm.envOr("FIRE_SPOILS", uint256(0)) == 1, "FIRE_SPOILS");
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        address ocean = vm.envOr("OCEAN", OCEAN_DEFAULT);

        vm.startBroadcast(pk);
        CrownSpoilsOfWar spoils = new CrownSpoilsOfWar(USDC, COLD, HOT, ocean, HOT);
        console2.log("CrownSpoilsOfWar", address(spoils));
        console2.log("coldBps", spoils.coldBps());
        console2.log("oceanBps", spoils.oceanBps());
        console2.log("oceanExternal", spoils.oceanExternal());
        vm.stopBroadcast();
        console2.log("MISSION spoils router deployed");
    }
}
