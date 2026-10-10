// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownRevenueSweep} from "../src/CrownRevenueSweep.sol";
import {CrownGoldConvert} from "../src/CrownGoldConvert.sol";

/// @notice Deploy Route A (RevenueSweep) + Route B (GoldConvert) for sealed $3M A+B.
/// Env: HOT_KEY (must be HOT). Optional: COLD=, ROUTER=
contract DeployRouteAB is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant COLD_DEFAULT = 0xBb3c14bBacD639797cB5c537fde370d1b7195521;
    address constant ROUTER_DEFAULT = 0x2626664c2603336E57B271c5C0b26F421741e481;
    address constant KXAU = 0x76822B470DeC1b94Df4219727288e7a196224853;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;

    uint256 constant TARGET_USDC = 1_500_000_000000; // $1.5M Route B

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        address cold = vm.envOr("COLD", COLD_DEFAULT);
        address router = vm.envOr("ROUTER", ROUTER_DEFAULT);

        vm.startBroadcast(pk);

        CrownRevenueSweep sweep = new CrownRevenueSweep(USDC, cold, HOT, HOT);
        console2.log("CrownRevenueSweep", address(sweep));

        CrownGoldConvert convert = new CrownGoldConvert(USDC, HOT, router, HOT);
        convert.setSellable(KXAU, true, 8);
        convert.setSellable(YRSS, true, 18);
        convert.setTargetUsdc(TARGET_USDC);
        console2.log("CrownGoldConvert", address(convert));

        vm.stopBroadcast();

        console2.log("MISSION Route A+B deployed");
        console2.log("coldBps", sweep.coldBps());
        console2.log("targetUsdc", convert.targetUsdc());
    }
}
