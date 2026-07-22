// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownRssDutchBond} from "../src/CrownRssDutchBond.sol";

/// @notice Reset Dutch auction clock + slash floor — arb bait for counterparty fills.
/// @dev KING_OK=1 FIRE_SLASH=1. Default floor $0.85, ceiling $0.99, 7d.
contract FireSlashDutch is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant DUTCH = 0x8A4C17c5FAB0ba334dAe4CdECa8BaC60a8Cc5E81;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(vm.envOr("KING_OK", uint256(0)) == 1, "KING_OK");
        require(vm.envOr("FIRE_SLASH", uint256(0)) == 1, "FIRE_SLASH");

        uint256 floor = vm.envOr("DUTCH_FLOOR", uint256(850_000)); // $0.85
        uint256 ceiling = vm.envOr("DUTCH_CEIL", uint256(990_000));
        uint256 duration = vm.envOr("DUTCH_DURATION", uint256(7 days));

        CrownRssDutchBond dutch = CrownRssDutchBond(DUTCH);
        console2.log("=== SLASH DUTCH ===");
        console2.log("priceBefore", dutch.currentPrice());
        console2.log("rssForBond", dutch.rssForBond());
        console2.log("newFloor", floor);
        console2.log("newCeil", ceiling);

        vm.startBroadcast(pk);
        dutch.armDutch(LANDING, floor, ceiling, duration, 500_000e6, true);
        vm.stopBroadcast();

        console2.log("priceAfter", dutch.currentPrice());
        console2.log("SLASH_OK", uint256(1));
    }
}
