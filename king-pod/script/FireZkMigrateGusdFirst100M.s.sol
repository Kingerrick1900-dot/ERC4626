// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ZkShieldLaw} from "./ZkShieldLaw.sol";

interface IGusdUnwrap {
    function unwrap(uint256 amount, address to) external returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

interface IEusd {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IZkRail {
    function zkSupply(uint256 assets, address onBehalf) external returns (uint256, uint256);
    function totalSupplied() external view returns (uint256);
}

/// @notice FIRE_ZK_MIGRATE_GUSD_100M=1 · HOT_KEY
/// @dev Kingdom gUSD @ 0x319A… holds eUSD reserves 1:1. HOT owns ~2.033B gUSD.
///      Path: unwrap 100M gUSD → eUSD on HOT → CrownZkMorphoRail.zkSupply(onBehalf=Safe).
/// @dev Live V3 migrateFirst100M() hard-reverts AwaitHandoff — this is the real first tranche.
contract FireZkMigrateGusdFirst100M is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant GUSD = 0x319A49BB274A826F889C6e7221FA82f24ac8bc5d;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant ZK_RAIL = 0xa787C47E04b38bcD84ceAd05ce903B0005E9Dda3;
    uint256 constant FIRST = 100_000_000 ether;

    function run() external {
        require(vm.envOr("FIRE_ZK_MIGRATE_GUSD_100M", uint256(0)) == 1, "FIRE_ZK_MIGRATE_GUSD_100M");
        ZkShieldLaw.requireFire(HOT);

        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 gBefore = IGusdUnwrap(GUSD).balanceOf(HOT);
        require(gBefore >= FIRST, "GUSD_BAL");
        uint256 railBefore = IZkRail(ZK_RAIL).totalSupplied();

        vm.startBroadcast(pk);
        IGusdUnwrap(GUSD).unwrap(FIRST, HOT);
        uint256 eBal = IEusd(EUSD).balanceOf(HOT);
        require(eBal >= FIRST, "UNWRAP_SHORT");
        IEusd(EUSD).approve(ZK_RAIL, FIRST);
        (uint256 assets,) = IZkRail(ZK_RAIL).zkSupply(FIRST, SAFE);
        vm.stopBroadcast();

        require(assets == FIRST, "SUPPLY_AMT");
        require(IEusd(EUSD).balanceOf(HOT) == eBal - FIRST, "EUSD_LEFT");
        require(IZkRail(ZK_RAIL).totalSupplied() == railBefore + FIRST, "RAIL_DELTA");

        console2.log("MIGRATED_FIRST_100M", FIRST);
        console2.log("HOT_GUSD_AFTER", IGusdUnwrap(GUSD).balanceOf(HOT));
        console2.log("RAIL_TOTAL", IZkRail(ZK_RAIL).totalSupplied());
        console2.log("MISSION first 100M gUSD unwrap -> ZK rail under Safe");
    }
}
