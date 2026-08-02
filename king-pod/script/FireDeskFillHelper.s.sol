// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownDeskFillHelper} from "../src/CrownDeskFillHelper.sol";

/// @notice Deploy public desk fill helper. KING_GO=1 FIRE_HELPER=1 to broadcast.
contract FireDeskFillHelper is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant DESK = 0xDbf7C4Ad01418ec1b753fa039d5e5B54aF4C065D;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO-GO");
        bool doFire = vm.envOr("FIRE_HELPER", uint256(0)) == 1;

        console2.log("=== DESK FILL HELPER ===");
        if (!doFire) {
            console2.log("PREFLIGHT - set FIRE_HELPER=1");
            return;
        }

        vm.startBroadcast(pk);
        CrownDeskFillHelper h = new CrownDeskFillHelper(DESK, USDC, RSS, LANDING);
        vm.stopBroadcast();
        console2.log("helper", address(h));
        console2.log("READY", uint256(1));
    }
}
