// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownCircuitBreaker} from "../src/CrownCircuitBreaker.sol";
import {MintGate} from "../src/MintGate.sol";

interface IYrss {
    function totalAssets() external view returns (uint256);
}

/// @notice Deploy AMO6 armor: CircuitBreaker + MintGate. ColdBufferLaw is abstract (inherit in AMOs).
/// Env: HOT_KEY, optional SAFE_ROUTER=, YRSS=
/// Gate: FIRE_AMO6=1 to broadcast (audit-first; King/KAR fires).
contract DeployAmo6Armor is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant YRSS_DEFAULT = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant COLD = 0xBb3c14bBacD639797cB5c537fde370d1b7195521;

    function run() external {
        require(vm.envOr("FIRE_AMO6", uint256(0)) == 1, "FIRE_AMO6");
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        address yrss = vm.envOr("YRSS", YRSS_DEFAULT);
        address safeRouter = vm.envOr("SAFE_ROUTER", address(0));
        uint256 baseline = IYrss(yrss).totalAssets();

        vm.startBroadcast(pk);

        // Enforce live ColdBuffer floor if still 0 (King-owned).
        (bool ok, bytes memory ret) =
            COLD.call(abi.encodeWithSignature("minBufferBps()"));
        if (ok && ret.length >= 32 && abi.decode(ret, (uint256)) < 3000) {
            (bool sok,) = COLD.call(abi.encodeWithSignature("setMinBufferBps(uint256)", 3000));
            require(sok, "COLD_BPS");
            console2.log("ColdBuffer minBufferBps -> 3000");
        }

        CrownCircuitBreaker brk = new CrownCircuitBreaker(HOT, safeRouter, baseline);
        console2.log("CrownCircuitBreaker", address(brk));
        console2.log("yRssBaseline", baseline);

        MintGate gate = new MintGate(HOT);
        console2.log("MintGate", address(gate));
        console2.log("canMint", gate.canMint());
        console2.log("unlocked", gate.unlocked());

        vm.stopBroadcast();
        console2.log("MISSION AMO6 armor deployed - audit surface live");
        console2.log("COLD", COLD);
    }
}
