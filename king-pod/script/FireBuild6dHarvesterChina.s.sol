// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ZkShieldLaw} from "./ZkShieldLaw.sol";
import {HarvesterChina} from "../src/HarvesterChina.sol";

/// @notice FIRE_BUILD6D_HARVESTER_CHINA=1 · ZK_SHIELD=1 · HOT_KEY
/// @dev Atomic Build 6d — deploys ONLY HarvesterChina. Crowns to Safe. live=true, not gated.
contract FireBuild6dHarvesterChina is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ZK_WALLET_GATE = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    address constant BASE_ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    address constant KRT = 0xe8a40d2E62588102dbD61e0afA86f9BABE402A98;
    address constant ORACLE = 0x95f552e81911e85c9BAb182c77AaFb719404655a;
    address constant SOVEREIGN_RAIL = 0x4ae38CD0d8A23347B13f88038BF9c1AB73639003;
    address constant NIGERIA_DESK = 0x4987b70136c5C4071900C6404b3b47C34142a234;
    /// @dev China rails (Polygon-deployed registry; wired as immutable refs on Base harvester).
    address constant ROYAL_CARD = 0xC532B0e5400524D2cA83B3FfC85B7AE96cCefcD7;
    address constant CIPS = 0xbb5B4439060A3F46d14826973fb30Ada661ff5F0; // Lakala acquiring corridor seat
    address constant PARALLEL_CHAIN = 0x9c0E36f7f6A9194f781Bf2e2c23c48281a23Ce8D; // card bridge / parallel settle

    function run() external {
        require(vm.envOr("FIRE_BUILD6D_HARVESTER_CHINA", uint256(0)) == 1, "FIRE_BUILD6D_HARVESTER_CHINA");
        ZkShieldLaw.requireFire(HOT);
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        HarvesterChina.Rails memory r = HarvesterChina.Rails({
            usdc: USDC,
            zkGate: ZK_WALLET_GATE,
            attest: BASE_ATTEST,
            king: SAFE,
            hot: HOT,
            krt: KRT,
            oracle: ORACLE,
            sovereignRail: SOVEREIGN_RAIL,
            nigeriaDesk: NIGERIA_DESK,
            cips: CIPS,
            parallelChain: PARALLEL_CHAIN,
            royalCard: ROYAL_CARD,
            owner: HOT
        });

        vm.startBroadcast(pk);
        HarvesterChina h = new HarvesterChina(r);
        h.transferOwnership(SAFE);
        vm.stopBroadcast();

        console2.log("HARVESTER_CHINA", address(h));
        console2.log("LIVE", h.live() ? 1 : 0);
        console2.log("FEE_BPS", h.FEE_BPS());
        console2.log("CIPS", h.cips());
        console2.log("PARALLEL", h.parallelChain());
        console2.log("ROYAL_CARD", h.royalCard());
    }
}
