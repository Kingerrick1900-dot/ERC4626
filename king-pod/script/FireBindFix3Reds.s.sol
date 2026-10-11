// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ZkShieldLaw} from "./ZkShieldLaw.sol";
import {CrownZkMorphoRail} from "../src/CrownZkMorphoRail.sol";
import {CrownZkMigrationExecutorV3_100T} from "../src/CrownZkMigrationExecutorV3_100T.sol";
import {CrownNigeriaDesk} from "../src/CrownNigeriaDesk.sol";
import {HarvesterChina} from "../src/HarvesterChina.sol";

/// @notice FIRE_BIND_FIX_3REDS=1 · ZK_SHIELD=1 · HOT_KEY
/// @dev Deploy only: updated rail + V3 executor (no AwaitHandoff) + corridor desks fee→Safe.
contract FireBindFix3Reds is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ZK_WALLET_GATE = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    address constant BASE_ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    address constant ORACLE = 0x95f552e81911e85c9BAb182c77AaFb719404655a;
    address constant KRT = 0xe8a40d2E62588102dbD61e0afA86f9BABE402A98;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant EUSD_ORACLE = 0x4153669Cc3671B6b8b68D47Fd852Ad1a48b950e0;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    address constant SOVEREIGN_RAIL = 0x4ae38CD0d8A23347B13f88038BF9c1AB73639003;
    address constant ROYAL_CARD = 0xC532B0e5400524D2cA83B3FfC85B7AE96cCefcD7;
    address constant CIPS = 0xbb5B4439060A3F46d14826973fb30Ada661ff5F0;
    address constant PARALLEL_CHAIN = 0x9c0E36f7f6A9194f781Bf2e2c23c48281a23Ce8D;

    function run() external {
        require(vm.envOr("FIRE_BIND_FIX_3REDS", uint256(0)) == 1, "FIRE_BIND_FIX_3REDS");
        ZkShieldLaw.requireFire(HOT);
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);

        // FIX 1 — rail with CapacityCheck + WalletMigrated on supply
        CrownZkMorphoRail rail = new CrownZkMorphoRail(MORPHO, ZK_WALLET_GATE, BASE_ATTEST, SAFE, HOT);
        rail.setRailParams(EUSD, RSS, EUSD_ORACLE, IRM, LLTV);
        rail.transferOwnership(SAFE);

        // FIX 2 — V3 executor, AwaitHandoff retired, wired to new rail
        CrownZkMigrationExecutorV3_100T exec = new CrownZkMigrationExecutorV3_100T(address(rail));

        // FIX 3 — corridor fees → Safe (not HOT)
        CrownNigeriaDesk desk =
            new CrownNigeriaDesk(USDC, ORACLE, KRT, ZK_WALLET_GATE, BASE_ATTEST, SAFE, SAFE, HOT);
        desk.transferOwnership(SAFE);

        HarvesterChina.Rails memory r = HarvesterChina.Rails({
            usdc: USDC,
            zkGate: ZK_WALLET_GATE,
            attest: BASE_ATTEST,
            king: SAFE,
            hot: SAFE,
            krt: KRT,
            oracle: ORACLE,
            sovereignRail: SOVEREIGN_RAIL,
            nigeriaDesk: address(desk),
            cips: CIPS,
            parallelChain: PARALLEL_CHAIN,
            royalCard: ROYAL_CARD,
            owner: HOT
        });
        HarvesterChina china = new HarvesterChina(r);
        china.transferOwnership(SAFE);

        vm.stopBroadcast();

        console2.log("RAIL", address(rail));
        console2.log("EXECUTOR_V3", address(exec));
        console2.log("NIGERIA_DESK", address(desk));
        console2.log("CHINA_HARVESTER", address(china));
        console2.log("DESK_FEE_SINK", desk.feeSink());
        console2.log("CHINA_FEE_SINK", china.hot());
        console2.log("EXEC_RAIL", exec.ZK_RAIL());
        console2.log("ZK_SHIELD", exec.ZK_SHIELD());
    }
}
