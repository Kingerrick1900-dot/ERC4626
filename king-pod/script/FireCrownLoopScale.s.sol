// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownLoopNative} from "../src/CrownLoopNative.sol";

interface IGateScale {
    function assertCanScale(uint256 flashUsdc) external view returns (bool);
    function gateBPassed() external view returns (bool);
    function scaleArmedTo() external view returns (uint256);
}

interface IERC20b {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @notice Fire 4 — scale $10M/$50M/$200M only if UnbreakableGate asserts.
/// @dev Set FLASH_USDC + GATE. Private relay: set PRIVATE_RPC (else public Base — honest).
contract FireCrownLoopScale is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LOOP_LIVE = 0xedBb3bCF9E31B37C748AeAaB6d86Cefe759F5D3a;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    uint256 constant LLTV = 860000000000000000;

    function run() external {
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        address gate = vm.envAddress("GATE");
        address loopAddr = vm.envOr("LOOP", LOOP_LIVE);
        uint256 flashUsdc = vm.envUint("FLASH_USDC"); // required — no silent 10k
        require(flashUsdc >= 10_000_000e6, "MIN_10M");
        uint256 eusdColl = vm.envOr("EUSD_COLL", (flashUsdc * 1e12 * 1e18 * 102) / (LLTV * 100));

        // Contract-enforced Gate B + scale arm + PQ
        IGateScale(gate).assertCanScale(flashUsdc);

        vm.startBroadcast(pk);
        IERC20b(EUSD).approve(loopAddr, eusdColl);
        CrownLoopNative(loopAddr).fire(flashUsdc, eusdColl);
        vm.stopBroadcast();

        console2.log("scaledFlash", flashUsdc);
        console2.log("fires", CrownLoopNative(loopAddr).fires());
        console2.log("totalFlashed", CrownLoopNative(loopAddr).totalFlashed());
        console2.log("hotUsdc", IERC20b(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913).balanceOf(HOT));
    }
}
