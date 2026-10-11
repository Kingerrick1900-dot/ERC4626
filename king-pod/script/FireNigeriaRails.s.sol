// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ZkShieldLaw} from "./ZkShieldLaw.sol";
import {CrownNigeriaRail} from "../src/CrownNigeriaRail.sol";

interface IKillMetricNR {
    function reportWeeklyUSDC()
        external
        returns (uint256 week, uint256 fees, uint256 target, bool green, bool nigeriaOnly);
}

/// @notice FIRE_NIGERIA_RAILS=1 · ZK_SHIELD=1 · HOT_KEY
/// @dev Opens Nigeria remittance corridor — desk + remittance harvester + KillMetric snapshot.
contract FireNigeriaRails is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant ZK_WALLET_GATE = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    address constant BASE_ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    address constant DESK = 0x4987b70136c5C4071900C6404b3b47C34142a234;
    address constant H_REMIT = 0xcFe3011983F713C9b132ae75540F66aACf82Ac9B;
    address constant KRT = 0xe8a40d2E62588102dbD61e0afA86f9BABE402A98;
    address constant ORACLE = 0x95f552e81911e85c9BAb182c77AaFb719404655a;
    address constant SOVEREIGN_RAIL = 0x4ae38CD0d8A23347B13f88038BF9c1AB73639003;
    address constant KILL = 0x51550e85baC735c46bcd830A9122051F6Aa95440;
    bytes32 constant MARKET_ID = 0x5e09a4f17a49a893570d8ccf539cef0fb464a5d184f7bd525f074e3d93a82f44;

    function run() external {
        require(vm.envOr("FIRE_NIGERIA_RAILS", uint256(0)) == 1, "FIRE_NIGERIA_RAILS");
        ZkShieldLaw.requireFire(HOT);
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);
        CrownNigeriaRail rail = new CrownNigeriaRail(
            ZK_WALLET_GATE,
            BASE_ATTEST,
            SAFE,
            HOT,
            DESK,
            H_REMIT,
            KRT,
            ORACLE,
            SOVEREIGN_RAIL,
            KILL,
            MARKET_ID,
            HOT
        );
        rail.fireOpen();
        rail.transferOwnership(SAFE);

        // Public kill-metric snapshot (HOT authorized)
        (uint256 week, uint256 fees, uint256 target, bool green, bool nigeriaOnly) =
            IKillMetricNR(KILL).reportWeeklyUSDC();
        vm.stopBroadcast();

        console2.log("NIGERIA_RAIL", address(rail));
        console2.log("OPEN", rail.open() ? 1 : 0);
        console2.log("DESK", rail.desk());
        console2.log("HARVESTER_REMIT", rail.harvesterRemittance());
        console2.log("KILL_WEEK", week);
        console2.log("KILL_FEES", fees);
        console2.log("KILL_TARGET", target);
        console2.log("KILL_GREEN", green ? 1 : 0);
        console2.log("NIGERIA_ONLY_MODE", nigeriaOnly ? 1 : 0);
        console2.log("MISSION Nigeria remittance rail OPEN - 2% USDC to HOT - KYC off-chain");
    }
}
