// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {KarSniper} from "../src/KarSniper.sol";

/// @notice Deploy KarSniper for KAR. Env: PRIVATE_KEY
contract DeployKarSniper is Script {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant KING_VAULT = 0xA1aFcb46a64C9173519180458C1cF302179c832a;
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        KarSniper sniper = new KarSniper(MORPHO, PA, YRSS, KING_VAULT, HOT);
        vm.stopBroadcast();

        console2.log("KarSniper", address(sniper));
        console2.log("morpho", MORPHO);
        console2.log("pa", PA);
        console2.log("vault", YRSS);
        console2.log("kingVault", KING_VAULT);
        console2.log("operator", HOT);
        console2.log("NOTE: HOT must Morpho.setAuthorization(sniper, true) before borrow path");
    }
}
