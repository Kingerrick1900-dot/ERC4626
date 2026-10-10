// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ZkShieldLaw} from "./ZkShieldLaw.sol";
import {HotOracle50k} from "../src/HotOracle50k.sol";

/// @notice FIRE_BUILD2_HOT_ORACLE=1 · ZK_SHIELD=1 · HOT_KEY
/// @dev Atomic Build 2 — deploys ONLY HotOracle50k. Crowns to Safe.
contract FireBuild2HotOracle is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant ZK_WALLET_GATE = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    address constant BASE_ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    address constant SOVEREIGN_RAIL = 0x4ae38CD0d8A23347B13f88038BF9c1AB73639003;
    /// @dev Optional — address(0) uses constant $13.50 Morpho floor.
    address constant CHAINLINK = address(0);

    function run() external {
        require(vm.envOr("FIRE_BUILD2_HOT_ORACLE", uint256(0)) == 1, "FIRE_BUILD2_HOT_ORACLE");
        ZkShieldLaw.requireFire(HOT);
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);
        HotOracle50k oracle =
            new HotOracle50k(ZK_WALLET_GATE, BASE_ATTEST, SAFE, SOVEREIGN_RAIL, CHAINLINK, HOT);
        oracle.transferOwnership(SAFE);
        vm.stopBroadcast();

        console2.log("HOT_ORACLE_50K", address(oracle));
    }
}
