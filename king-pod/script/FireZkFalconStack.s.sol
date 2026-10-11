// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownHotOracle50kZk} from "../src/CrownHotOracle50kZk.sol";
import {CrownHarvesterZk} from "../src/CrownHarvesterZk.sol";
import {CrownKRT} from "../src/CrownKRT.sol";
import {CrownGusd} from "../src/CrownGusd.sol";
import {Crown369} from "../src/Crown369.sol";
import {ZkShieldLaw} from "./ZkShieldLaw.sol";

interface IMorphoZF {
    function isLltvEnabled(uint256) external view returns (bool);
}

/// @notice FIRE_ZK_FALCON_STACK=1 · ZK_SHIELD=1 · HOT_KEY
/// @dev Deploy ZK-gated Falcon (oracle/harvester with on-chain WalletGate+borders). Crown to Safe.
contract FireZkFalconStack is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant ZK_WALLET_GATE = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    address constant BASE_ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    uint256 constant LLTV_385 = 385000000000000000;

    function run() external {
        require(vm.envOr("FIRE_ZK_FALCON_STACK", uint256(0)) == 1, "FIRE_ZK_FALCON_STACK");
        ZkShieldLaw.requireFire(HOT);
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        require(IMorphoZF(MORPHO).isLltvEnabled(LLTV_385), "LLTV");

        vm.startBroadcast(pk);

        CrownHotOracle50kZk zOracle = new CrownHotOracle50kZk(HOT, ZK_WALLET_GATE, BASE_ATTEST);
        CrownKRT krt = new CrownKRT(HOT, SAFE);
        CrownGusd gusd = new CrownGusd(HOT);
        gusd.mint(HOT, 1_000_000e18);
        krt.mint(HOT, 1_000_000e18);
        CrownHarvesterZk harv = new CrownHarvesterZk(MORPHO, ZK_WALLET_GATE, BASE_ATTEST, HOT, SAFE);
        Crown369 c369 = new Crown369(MORPHO, RSS, IRM, LLTV_385, HOT);
        c369.setTokens(address(krt), EUSD, address(gusd), address(zOracle));
        (bytes32 idK, bytes32 idE, bytes32 idG) = c369.fireBase3();
        harv.setRailParams(EUSD, RSS, address(zOracle), IRM, LLTV_385);

        zOracle.transferOwnership(SAFE);
        krt.transferOwnership(SAFE);
        gusd.transferOwnership(SAFE);
        harv.transferOwnership(SAFE);
        c369.transferOwnership(SAFE);

        vm.stopBroadcast();

        console2.log("ZK_ORACLE", address(zOracle));
        console2.log("ZK_KRT", address(krt));
        console2.log("ZK_GUSD", address(gusd));
        console2.log("ZK_HARVESTER", address(harv));
        console2.log("ZK_CROWN369", address(c369));
        console2.log("MKT_KRT", uint256(idK));
        console2.log("MKT_EUSD", uint256(idE));
        console2.log("MKT_GUSD", uint256(idG));
        console2.log("MISSION ZK Falcon stack lit - Safe owns - on-chain WalletGate+borders");
    }
}
