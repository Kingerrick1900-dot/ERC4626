// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ZkShieldLaw} from "./ZkShieldLaw.sol";

interface ISweep3 {
    function sweep(address token, uint256 amount, address to) external;
}

interface ISweepTo {
    function sweep(address token, address to, uint256 amount) external;
}

interface IEusd {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IZkRail {
    function zkSupply(uint256 assets, address onBehalf) external returns (uint256, uint256);
    function totalSupplied() external view returns (uint256);
}

/// @notice FIRE_ZK_MIGRATE_SWEEP3=1 · SWEEP_FROM · SWEEP_STYLE=3|to · HOT_KEY · ZK_SHIELD=1
/// @dev style 3: sweep(token,amt,to) · style to: sweep(token,to,amt)
contract FireZkMigrateSweep3Chunk is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant ZK_RAIL = 0xa787C47E04b38bcD84ceAd05ce903B0005E9Dda3;

    function run() external {
        require(vm.envOr("FIRE_ZK_MIGRATE_SWEEP3", uint256(0)) == 1, "FIRE_ZK_MIGRATE_SWEEP3");
        ZkShieldLaw.requireFire(HOT);
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        address from = vm.envAddress("SWEEP_FROM");
        string memory style = vm.envOr("SWEEP_STYLE", string("3"));
        uint256 amt = IEusd(EUSD).balanceOf(from);
        require(amt > 0, "EMPTY");
        uint256 railBefore = IZkRail(ZK_RAIL).totalSupplied();

        vm.startBroadcast(pk);
        if (keccak256(bytes(style)) == keccak256(bytes("to"))) {
            ISweepTo(from).sweep(EUSD, HOT, amt);
        } else {
            ISweep3(from).sweep(EUSD, amt, HOT);
        }
        require(IEusd(EUSD).balanceOf(HOT) >= amt, "SWEEP_FAIL");
        IEusd(EUSD).approve(ZK_RAIL, amt);
        (uint256 assets,) = IZkRail(ZK_RAIL).zkSupply(amt, SAFE);
        vm.stopBroadcast();

        require(assets == amt, "SUPPLY");
        require(IZkRail(ZK_RAIL).totalSupplied() == railBefore + amt, "RAIL");
        console2.log("SWEPT_FROM", from);
        console2.log("MIGRATED", amt);
        console2.log("RAIL_TOTAL", IZkRail(ZK_RAIL).totalSupplied());
    }
}
