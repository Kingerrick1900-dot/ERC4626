// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownEliteElephant} from "../src/CrownEliteElephant.sol";

interface IMorphoFire {
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IOracleFire {
    function price() external view returns (uint256);
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
}

/// @notice FIRE_ELITE_ELEPHANT=1 · ZK_SHIELD=1 · HOT_KEY
/// @dev Atomic Gate → Elephant reseat on SOV. PAR deferred (no idle / LP peel).
contract FireEliteElephant is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0x22E2F66a26eA8d01E0Bb4154ef4DfB0304a34f2d;
    address constant LEGACY_GATE = 0x76fa390951fA31185490378F46B6e9F05bA4bC3b;
    bytes32 constant SOV = 0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b;
    bytes32 constant PAR = 0x1bfd981b9905c55085390f7dedad00f32cd43527acf9dabe7de758e3f6c42134;

    function run() external {
        require(vm.envOr("FIRE_ELITE_ELEPHANT", uint256(0)) == 1, "FIRE_ELITE_ELEPHANT");
        require(vm.envOr("ZK_SHIELD", uint256(0)) == 1, "ZK_SHIELD_REQUIRED");
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        require(IOracleFire(ORACLE).owner() == HOT, "NOT_ORACLE_OWNER");

        (, uint128 bor, uint128 coll) = IMorphoFire(MORPHO).position(SOV, LEGACY_GATE);
        require(bor > 0 && coll > 0, "NO_LEGACY_POS");
        console2.log("legacyBorShares", uint256(bor));
        console2.log("legacyColl", uint256(coll));
        console2.log("oraclePrice", IOracleFire(ORACLE).price());
        console2.log("liqPrice", uint256(14481091385879511120322260));

        vm.startBroadcast(pk);
        CrownEliteElephant el = new CrownEliteElephant(MORPHO, USDC, RSS, ORACLE, HOT);
        // Elephant must own oracle for atomic self-del + restore inside the flash.
        IOracleFire(ORACLE).transferOwnership(address(el));
        el.fire();
        require(IOracleFire(ORACLE).owner() == HOT, "ORACLE_NOT_RETURNED");
        vm.stopBroadcast();

        (, uint128 borAfter, uint128 collAfter) = IMorphoFire(MORPHO).position(SOV, LEGACY_GATE);
        (, uint128 borEl, uint128 collEl) = IMorphoFire(MORPHO).position(SOV, address(el));
        (, uint128 borPar, uint128 collPar) = IMorphoFire(MORPHO).position(PAR, address(el));
        console2.log("ELEPHANT", address(el));
        console2.log("legacyCollAfter", uint256(collAfter));
        console2.log("legacyBorAfter", uint256(borAfter));
        console2.log("elephantSovColl", uint256(collEl));
        console2.log("elephantSovBorShares", uint256(borEl));
        console2.log("parColl", uint256(collPar));
        console2.log("parBorShares", uint256(borPar));
        console2.log("oracleAfter", IOracleFire(ORACLE).price());
        require(collAfter == 0 && borAfter == 0, "GATE_NOT_FLAT");
        require(collEl > 0 && borEl > 0, "ELEPHANT_NOT_SEATED");
        console2.log("MISSION elephant walked");
    }
}
