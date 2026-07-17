// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {KingPodFactory} from "../src/KingPodFactory.sol";

contract Deploy is Script {
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant KING = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        KingPodFactory factory = new KingPodFactory(KING);
        address pod = factory.deploy(RSS, USDC, KING);
        console2.log("factory", address(factory));
        console2.log("pod", pod);
        vm.stopBroadcast();
    }
}
