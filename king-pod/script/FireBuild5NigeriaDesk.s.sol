// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ZkShieldLaw} from "./ZkShieldLaw.sol";
import {CrownNigeriaDesk} from "../src/CrownNigeriaDesk.sol";

/// @notice FIRE_BUILD5_NIGERIA_DESK=1 · ZK_SHIELD=1 · HOT_KEY
/// @dev Atomic Build 5 — deploys ONLY CrownNigeriaDesk. Crowns to Safe.
contract FireBuild5NigeriaDesk is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ZK_WALLET_GATE = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    address constant BASE_ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    address constant ORACLE = 0x95f552e81911e85c9BAb182c77AaFb719404655a;
    address constant KRT = 0xe8a40d2E62588102dbD61e0afA86f9BABE402A98;

    function run() external {
        require(vm.envOr("FIRE_BUILD5_NIGERIA_DESK", uint256(0)) == 1, "FIRE_BUILD5_NIGERIA_DESK");
        ZkShieldLaw.requireFire(HOT);
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);
        CrownNigeriaDesk desk =
            new CrownNigeriaDesk(USDC, ORACLE, KRT, ZK_WALLET_GATE, BASE_ATTEST, SAFE, HOT, HOT);
        desk.transferOwnership(SAFE);
        vm.stopBroadcast();

        console2.log("NIGERIA_DESK", address(desk));
        console2.log("FEE_BPS", desk.FEE_BPS());
    }
}
