// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ZkShieldLaw} from "./ZkShieldLaw.sol";
import {CrownMarket_Base_KRT_RSS} from "../src/CrownMarket_Base_KRT_RSS.sol";

/// @notice FIRE_BUILD4_CROWN_MARKET=1 · ZK_SHIELD=1 · HOT_KEY
/// @dev Atomic Build 4 — deploys market factory + fires one Base KRT/RSS Morpho market.
contract FireBuild4CrownMarket is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant ZK_WALLET_GATE = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    address constant BASE_ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    address constant KRT = 0xe8a40d2E62588102dbD61e0afA86f9BABE402A98;
    address constant ORACLE = 0x95f552e81911e85c9BAb182c77AaFb719404655a;
    address constant SOVEREIGN_RAIL = 0x4ae38CD0d8A23347B13f88038BF9c1AB73639003;

    function run() external {
        require(vm.envOr("FIRE_BUILD4_CROWN_MARKET", uint256(0)) == 1, "FIRE_BUILD4_CROWN_MARKET");
        ZkShieldLaw.requireFire(HOT);
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);
        CrownMarket_Base_KRT_RSS mkt = new CrownMarket_Base_KRT_RSS(
            MORPHO, ZK_WALLET_GATE, BASE_ATTEST, SOVEREIGN_RAIL, SAFE, KRT, RSS, ORACLE, IRM, HOT
        );
        bytes32 id = mkt.fire();
        mkt.transferOwnership(SAFE);
        vm.stopBroadcast();

        console2.log("CROWN_MARKET", address(mkt));
        console2.log("MARKET_ID", uint256(id));
        console2.logBytes32(id);
        console2.log("POLICY_LLTV", mkt.policyLltv());
        console2.log("MORPHO_LLTV", mkt.morphoLltv());
    }
}
