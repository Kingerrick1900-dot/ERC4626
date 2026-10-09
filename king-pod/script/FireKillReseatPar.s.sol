// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownKillReseatPar} from "../src/CrownKillReseatPar.sol";

interface IMorphoK {
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IOracleK {
    function price() external view returns (uint256);
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
}

/// @notice FIRE_KILL_RESEAT_PAR=1 · ZK_SHIELD=1 · HOT_KEY
/// @dev Kill Elephant $3M SOV debt via own-LP bad-debt unwind · reseat RSS on PAR · no draw.
contract FireKillReseatPar is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0x22E2F66a26eA8d01E0Bb4154ef4DfB0304a34f2d;
    address constant ELEPHANT = 0x03bdf75d11237C0560F48527F360640d9c7ddCAa;
    address constant KF = 0x16a3a6d50e80D70C873645789afCECf8B8b6aDC9;
    address constant CF = 0x37C9b6f79cA311B40083363Eb231E62B980Fa646;
    bytes32 constant SOV = 0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b;
    bytes32 constant PAR = 0x1bfd981b9905c55085390f7dedad00f32cd43527acf9dabe7de758e3f6c42134;

    function run() external {
        require(vm.envOr("FIRE_KILL_RESEAT_PAR", uint256(0)) == 1, "FIRE_KILL_RESEAT_PAR");
        require(vm.envOr("ZK_SHIELD", uint256(0)) == 1, "ZK_SHIELD_REQUIRED");
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        require(IOracleK(ORACLE).owner() == HOT, "NOT_ORACLE_OWNER");

        (, uint128 bor, uint128 coll) = IMorphoK(MORPHO).position(SOV, ELEPHANT);
        require(bor > 0 && coll > 0, "NO_ELEPHANT_POS");
        console2.log("elephantBorShares", uint256(bor));
        console2.log("elephantColl", uint256(coll));

        (uint256 kfSup,,) = IMorphoK(MORPHO).position(SOV, KF);
        (uint256 cfSup,,) = IMorphoK(MORPHO).position(SOV, CF);
        console2.log("kfSupplyShares", kfSup);
        console2.log("cfSupplyShares", cfSup);

        vm.startBroadcast(pk);
        CrownKillReseatPar killer = new CrownKillReseatPar(MORPHO, USDC, RSS, ORACLE, HOT);
        IOracleK(ORACLE).transferOwnership(address(killer));
        killer.killAndReseat();
        require(IOracleK(ORACLE).owner() == HOT, "ORACLE_NOT_RETURNED");
        vm.stopBroadcast();

        (, uint128 elBor, uint128 elColl) = IMorphoK(MORPHO).position(SOV, ELEPHANT);
        (, uint128 kBor, uint128 kColl) = IMorphoK(MORPHO).position(PAR, address(killer));
        (uint128 sa,, uint128 ba,,,) = IMorphoK(MORPHO).market(SOV);

        console2.log("KILLER", address(killer));
        console2.log("elephantBorAfter", uint256(elBor));
        console2.log("elephantCollAfter", uint256(elColl));
        console2.log("parColl", uint256(kColl));
        console2.log("parBor", uint256(kBor));
        console2.log("sovSupplyAssets", uint256(sa));
        console2.log("sovBorrowAssets", uint256(ba));
        console2.log("oraclePrice", IOracleK(ORACLE).price());
        require(elBor == 0, "ELEPHANT_DEBT_LIVE");
        require(kColl > 0 && kBor == 0, "PAR_NOT_COLL_ONLY");
        console2.log("MISSION kill reseat par — $3M dead — $4.28B rail coll seated — no draw");
    }
}
