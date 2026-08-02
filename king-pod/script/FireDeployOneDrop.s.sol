// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownOneDrop} from "../src/CrownOneDrop.sol";

/// @notice Deploy CrownOneDrop handoff on Base. KING_OK=1 FIRE_ONEDROP_DEPLOY=1
contract FireDeployOneDrop is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant AERO_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant AERO_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    address constant KUSD = 0x0FEA62084A024544891f03035E85401C2C886c1b;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant CDP = 0x9F9356dd8B17f58d03f3Db84e81541cdABBD5768;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_ONEDROP_DEPLOY", uint256(0)) == 1, "NO_FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);
        CrownOneDrop d = new CrownOneDrop(
            MORPHO,
            AERO_ROUTER,
            AERO_FACTORY,
            KUSD,
            USDC,
            RSS,
            CDP,
            LANDING,
            ORACLE,
            IRM,
            LLTV
        );
        d.transferOwnership(HOT);
        vm.stopBroadcast();

        console2.log("CrownOneDrop", address(d));
        console2.log("landing", LANDING);
        console2.log("cdp", CDP);
        console2.log("kusd", KUSD);
    }
}
