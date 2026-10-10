// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ZkShieldLaw} from "./ZkShieldLaw.sol";
import {HarvesterArb} from "../src/HarvesterArb.sol";

/// @notice FIRE_BUILD6C_HARVESTER_ARB=1 · ZK_SHIELD=1 · HOT_KEY
/// @dev Atomic Build 6c — deploys ONLY HarvesterArb. Crowns to Safe.
///      Optional pool addrs: ARB_POOL_BASE / ARB_POOL_POLYGON / ARB_POOL_SCROLL
contract FireBuild6cHarvesterArb is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ZK_WALLET_GATE = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    address constant BASE_ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;

    function run() external {
        require(vm.envOr("FIRE_BUILD6C_HARVESTER_ARB", uint256(0)) == 1, "FIRE_BUILD6C_HARVESTER_ARB");
        ZkShieldLaw.requireFire(HOT);
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        address poolBase = vm.envOr("ARB_POOL_BASE", address(0));
        address poolPoly = vm.envOr("ARB_POOL_POLYGON", address(0));
        address poolScroll = vm.envOr("ARB_POOL_SCROLL", address(0));

        vm.startBroadcast(pk);
        HarvesterArb h = new HarvesterArb(
            USDC, ZK_WALLET_GATE, BASE_ATTEST, SAFE, HOT, poolBase, poolPoly, poolScroll, HOT
        );
        h.transferOwnership(SAFE);
        vm.stopBroadcast();

        console2.log("HARVESTER_ARB", address(h));
        console2.log("HOT", h.hot());
    }
}
