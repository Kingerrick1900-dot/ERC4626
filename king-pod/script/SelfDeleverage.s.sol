// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MorphoKingDesk} from "../src/MorphoKingDesk.sol";

/// @dev Manual self-deleverage. Env: PRIVATE_KEY, DESK, REPAY_USDC (6 decimals raw).
contract SelfDeleverage is Script {
    address constant KING = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address desk = vm.envAddress("DESK");
        uint256 repay = vm.envUint("REPAY_USDC");
        vm.startBroadcast(pk);
        MorphoKingDesk(desk).selfDeleverage(repay);
        console2.log("HF after", MorphoKingDesk(desk).healthFactor(KING));
        vm.stopBroadcast();
    }
}
