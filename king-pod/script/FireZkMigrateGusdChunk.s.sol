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

/// @notice FIRE_ZK_MIGRATE_GUSD_CHUNK=1 · MIGRATE_AMT (wei) · HOT_KEY · ZK_SHIELD=1
/// @dev Unwrap MIGRATE_AMT gUSD → zkSupply to Safe. Caps to HOT gUSD balance.
contract FireZkMigrateGusdChunk is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant GUSD = 0x319A49BB274A826F889C6e7221FA82f24ac8bc5d;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant ZK_RAIL = 0xa787C47E04b38bcD84ceAd05ce903B0005E9Dda3;

    function run() external {
        require(vm.envOr("FIRE_ZK_MIGRATE_GUSD_CHUNK", uint256(0)) == 1, "FIRE_ZK_MIGRATE_GUSD_CHUNK");
        ZkShieldLaw.requireFire(HOT);

        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 want = vm.envUint("MIGRATE_AMT");
        require(want > 0, "AMT");
        uint256 gBal = IGusdUnwrap(GUSD).balanceOf(HOT);
        uint256 amt = want > gBal ? gBal : want;
        require(amt > 0, "NO_GUSD");

        uint256 railBefore = IZkRail(ZK_RAIL).totalSupplied();

        vm.startBroadcast(pk);
        IGusdUnwrap(GUSD).unwrap(amt, HOT);
        IEusd(EUSD).approve(ZK_RAIL, amt);
        (uint256 assets,) = IZkRail(ZK_RAIL).zkSupply(amt, SAFE);
        vm.stopBroadcast();

        require(assets == amt, "SUPPLY_AMT");
        require(IZkRail(ZK_RAIL).totalSupplied() == railBefore + amt, "RAIL_DELTA");

        console2.log("MIGRATED_CHUNK", amt);
        console2.log("HOT_GUSD_AFTER", IGusdUnwrap(GUSD).balanceOf(HOT));
        console2.log("RAIL_TOTAL", IZkRail(ZK_RAIL).totalSupplied());
    }
}
