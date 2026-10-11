// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownZkIdleEngineer} from "../src/zk/CrownZkIdleEngineer.sol";
import {CrownGateV2} from "../src/CrownGateV2.sol";

interface IZkF {
    function isProven(address) external view returns (bool);
}

interface IMorphoF {
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IYrssF {
    function maxWithdraw(address) external view returns (uint256);
    function totalAssets() external view returns (uint256);
}

/// @notice FIRE: engineer King into Morpho IDLE (ZK mandatory).
/// @dev FIRE_ZK_IDLE=1 ZK_SHIELD=1 HOT_KEY
///      IDLE_AMT=1100000 (whole USDC) or 6dp raw
///      GATE=0x76fa… (live CrownGateV2)
contract FireZkIdleEngineer is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ZK = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    address constant LIVE_GATE = 0x76fa390951fA31185490378F46B6e9F05bA4bC3b;
    bytes32 constant IDLE = 0x38c846197ac32a752a60c25d4536ebb0c3920c532e9a859c38c91efb7b8c2abb;
    bytes32 constant SOV = 0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b;

    function run() external {
        require(vm.envOr("FIRE_ZK_IDLE", uint256(0)) == 1, "FIRE_ZK_IDLE");
        require(vm.envOr("ZK_SHIELD", uint256(0)) == 1, "ZK_SHIELD_REQUIRED");
        require(vm.envOr("TRANSPARENT_OK", uint256(0)) == 0, "TRANSPARENT_FORBIDDEN");
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        require(IZkF(ZK).isProven(HOT), "NOT_PROVEN");

        address gateAddr = vm.envOr("GATE", LIVE_GATE);
        uint256 amt = vm.envOr("IDLE_AMT", uint256(1_100_000));
        if (amt < 1e9) amt *= 1e6;

        console2.log("zkProven", true);
        console2.log("idleAmt", amt);
        console2.log("gate", gateAddr);
        console2.log("totalAssetsBefore", IYrssF(YRSS).totalAssets());

        vm.startBroadcast(pk);
        CrownZkIdleEngineer eng =
            new CrownZkIdleEngineer(MORPHO, USDC, YRSS, ZK, gateAddr, HOT, HOT);
        console2.log("CrownZkIdleEngineer", address(eng));
        CrownGateV2(gateAddr).setOperator(address(eng), true);
        eng.engineerIdleSovMatch(amt);
        vm.stopBroadcast();

        (uint256 idleShares,,) = IMorphoF(MORPHO).position(IDLE, YRSS);
        (uint256 sovShares,,) = IMorphoF(MORPHO).position(SOV, YRSS);
        (, uint128 gBor, uint128 gColl) = IMorphoF(MORPHO).position(SOV, gateAddr);
        console2.log("idleShares", idleShares);
        console2.log("sovShares", sovShares);
        console2.log("gateColl", uint256(gColl));
        console2.log("gateBorShares", uint256(gBor));
        console2.log("maxWithdraw", IYrssF(YRSS).maxWithdraw(HOT));
        console2.log("totalAssetsAfter", IYrssF(YRSS).totalAssets());
        console2.log("KING_IN_IDLE", idleShares > 0 ? uint256(1) : uint256(0));
        console2.log("ZK_SHIELD", uint256(1));
        require(idleShares > 0, "NOT_IN_IDLE");
    }
}
