// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownRevenueSweep} from "../src/CrownRevenueSweep.sol";

interface IERC20A {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice Fire Route A sweep. Env: SWEEP=, SOURCE=, AMOUNT= (0=full), ADD_SOURCE=1 to allowlist.
contract FireRevenueSweep is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    function run() external {
        address sweepAddr = vm.envAddress("SWEEP");
        address source = vm.envAddress("SOURCE");
        uint256 amount = vm.envOr("AMOUNT", uint256(0));

        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        CrownRevenueSweep sweep = CrownRevenueSweep(sweepAddr);

        vm.startBroadcast(pk);

        if (vm.envOr("ADD_SOURCE", uint256(0)) == 1) {
            sweep.setFeeSource(source, true);
            console2.log("allowlisted", source);
        }

        // Source must approve sweeper (if source is HOT, approve here)
        if (source == HOT) {
            uint256 bal = IERC20A(USDC).balanceOf(HOT);
            uint256 need = amount == 0 ? bal : amount;
            IERC20A(USDC).approve(sweepAddr, need);
        }

        uint256 swept = sweep.sweep(source, amount);
        (uint256 total, uint256 toCold, uint256 toHot, uint256 bps) = sweep.book();

        vm.stopBroadcast();

        console2.log("swept", swept);
        console2.log("totalSwept", total);
        console2.log("totalCold", toCold);
        console2.log("totalHot", toHot);
        console2.log("coldBps", bps);
        console2.log("MISSION Route A sweep fired");
    }
}
