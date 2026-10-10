// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ZkShieldLaw} from "./ZkShieldLaw.sol";
import {KillMetric} from "../src/KillMetric.sol";

/// @notice FIRE_BUILD7_KILL_METRIC=1 · ZK_SHIELD=1 · HOT_KEY
/// @dev Atomic Build 7 — deploys ONLY KillMetric. Crowns to Safe.
contract FireBuild7KillMetric is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant ZK_WALLET_GATE = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    address constant BASE_ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    address constant SOVEREIGN_RAIL = 0x4ae38CD0d8A23347B13f88038BF9c1AB73639003;
    address constant ORACLE = 0x95f552e81911e85c9BAb182c77AaFb719404655a;
    address constant KRT = 0xe8a40d2E62588102dbD61e0afA86f9BABE402A98;
    bytes32 constant MARKET_ID = 0x5e09a4f17a49a893570d8ccf539cef0fb464a5d184f7bd525f074e3d93a82f44;
    address constant NIGERIA_DESK = 0x4987b70136c5C4071900C6404b3b47C34142a234;
    address constant H_REMIT = 0xcFe3011983F713C9b132ae75540F66aACf82Ac9B;
    address constant H_FEES = 0x09a7B22CE2156629D5690fAb927cC04a5a0ae19a;
    address constant H_ARB = 0xE20e27a6044E70Be5EFb1aF63eC3e47491cBA526;
    address constant H_CHINA = 0x09BB01DB088efD2de0e1a4E043B62FE58B72f219;

    function run() external {
        require(vm.envOr("FIRE_BUILD7_KILL_METRIC", uint256(0)) == 1, "FIRE_BUILD7_KILL_METRIC");
        ZkShieldLaw.requireFire(HOT);
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        KillMetric.Registry memory r = KillMetric.Registry({
            zkGate: ZK_WALLET_GATE,
            attest: BASE_ATTEST,
            king: SAFE,
            hot: HOT,
            sovereignRail: SOVEREIGN_RAIL,
            oracle: ORACLE,
            krt: KRT,
            marketId: MARKET_ID,
            nigeriaDesk: NIGERIA_DESK,
            harvesterRemittance: H_REMIT,
            harvesterFees: H_FEES,
            harvesterArb: H_ARB,
            harvesterChina: H_CHINA,
            owner: HOT
        });

        vm.startBroadcast(pk);
        KillMetric km = new KillMetric(r);
        km.transferOwnership(SAFE);
        vm.stopBroadcast();

        (uint256 rem, uint256 fees, uint256 arb, uint256 china, uint256 total) = km.readAllLines();
        console2.log("KILL_METRIC", address(km));
        console2.log("TARGET_WEEK1", km.TARGET_WEEK1());
        console2.log("TARGET_WEEK4", km.TARGET_WEEK4());
        console2.log("READ_REMIT", rem);
        console2.log("READ_FEES", fees);
        console2.log("READ_ARB", arb);
        console2.log("READ_CHINA", china);
        console2.log("READ_TOTAL", total);
        console2.log("NIGERIA_ONLY", km.nigeriaOnlyMode() ? 1 : 0);
    }
}
