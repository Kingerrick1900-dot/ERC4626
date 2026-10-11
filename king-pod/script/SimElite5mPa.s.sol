// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

/// @notice Fork-only runner notes for the elite $5M PA path.
/// @dev Use the forge test: `forge test --match-test test_elite_5m_pa_cap_unused_path -vvv --fork-url $BASE_RPC_URL`
///      Live fire requires real USDC on yRSS idle (or foreign PA) — do not broadcast this stub.
contract SimElite5mPa is Script {
    uint256 constant ELITE_5M = 5_000_000e6;

    function run() external view {
        console2.log("ELITE_5M", ELITE_5M);
        console2.log("RUN: forge test --match-contract SimElite5mPaTest -vvv --fork-url $BASE_RPC_URL");
        console2.log("PATH: yRSS idle seed -> PA.reallocateTo RSS/$1 -> borrow 5M to HOT");
        console2.log("CAP: flowCaps maxIn=5e12 on markets 0x40ac and 0x41c0 (spendable budget)");
    }
}
