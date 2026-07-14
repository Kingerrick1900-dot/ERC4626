// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownFlashArb} from "../src/CrownFlashArb.sol";

contract DeployCrownFlashArb is Script {
    address constant ROUTER = 0x13734BffdDFf6CbDE474B3F5467d86e813232577;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant KING = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        // Operator = bot signer (same key unless OPERATOR_ADDRESS set)
        address operator = vm.envOr("OPERATOR_ADDRESS", deployer);

        vm.startBroadcast(pk);
        CrownFlashArb arb = new CrownFlashArb(ROUTER, USDC, KING, KING, operator);
        vm.stopBroadcast();

        console2.log("CrownFlashArb", address(arb));
        console2.log("router", address(arb.router()));
        console2.log("operator", arb.operator());
        console2.log("treasury", arb.treasury());
        console2.log("owner", arb.owner());
    }
}
