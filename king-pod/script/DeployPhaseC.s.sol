// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {KingPhaseCBorrow} from "../src/KingPhaseCBorrow.sol";
import {KingMoneyMarket} from "../src/KingMoneyMarket.sol";

/// @dev Deploy Phase C helper and set market operator to allow borrowTo from helper.
///      Run AFTER Option A pod is live. Does not move funds until execute().
contract DeployPhaseC is Script {
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant KING = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MARKET = 0x50A61cA6b06563f1A44f7F2186A325b5301e2578;
    // Team treasury = King until Crown names a separate address
    address constant TEAM = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        KingPhaseCBorrow phaseC = new KingPhaseCBorrow(USDC, MARKET, KING, TEAM, KING);
        // Grant PhaseC without removing Pod operator
        KingMoneyMarket(MARKET).setOperatorAuth(address(phaseC), true);
        console2.log("phaseC", address(phaseC));
        vm.stopBroadcast();
    }
}
