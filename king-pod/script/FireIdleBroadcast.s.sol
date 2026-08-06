// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownEngineerIdle} from "../src/CrownEngineerIdle.sol";

interface IMorphoAuth {
    function setAuthorization(address, bool) external;
}

/// @notice Broadcast idle position: Morpho sees ask, Morpho loans ask.
/// Env: PRIVATE_KEY, optional ASK (default 1_000_000e6), optional FIRE=1, optional SEEDER=
contract FireIdleBroadcast is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant MID = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        uint256 ask = vm.envOr("ASK", uint256(1_000_000e6));
        address seeder = vm.envOr("SEEDER", address(0));
        uint256 fire = vm.envOr("FIRE", uint256(0));

        vm.startBroadcast(pk);

        CrownEngineerIdle eng;
        if (seeder == address(0)) {
            eng = new CrownEngineerIdle(MORPHO, USDC, HOT, LANDING, MID);
            IMorphoAuth(MORPHO).setAuthorization(address(eng), true);
            console2.log("deployed", address(eng));
        } else {
            eng = CrownEngineerIdle(seeder);
        }

        if (fire == 1) {
            eng.broadcastIdleLoan(ask);
            console2.log("peakIdle", eng.lastPeakIdle());
            console2.log("loaned", eng.lastLoan());
        }

        vm.stopBroadcast();
    }
}
