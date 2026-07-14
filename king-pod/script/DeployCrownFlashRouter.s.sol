// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownFlashRouter} from "../src/CrownFlashRouter.sol";

contract DeployCrownFlashRouter is Script {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant KING = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    uint256 constant FEE_BPS = 5; // 0.05% Aave-style

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        CrownFlashRouter router = new CrownFlashRouter(MORPHO, USDC, KING, FEE_BPS, KING);
        vm.stopBroadcast();
        console2.log("CrownFlashRouter", address(router));
        console2.log("feeBps", router.feeBps());
        console2.log("treasury", router.treasury());
    }
}
