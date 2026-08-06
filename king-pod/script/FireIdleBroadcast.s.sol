// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownEngineerIdle} from "../src/CrownEngineerIdle.sol";

interface IMorphoAuth {
    function setAuthorization(address, bool) external;
}

interface IERC20S {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice Mission fire: engineer idle → Morpho loans ASK to Landing.
/// Env:
///   PRIVATE_KEY
///   FIRE=1
///   TO_LANDING=1   (0 = rematch broadcast only)
///   ASK            (default 700_000e6)
///   SEEDER         (default live 0x68F4…8866)
contract FireIdleBroadcast is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant MID = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;
    address constant LIVE_SEEDER = 0x68F439486E72765e2CA019FE2a55038090bd8866;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        uint256 ask = vm.envOr("ASK", uint256(700_000e6));
        address seeder = vm.envOr("SEEDER", LIVE_SEEDER);
        uint256 fire = vm.envOr("FIRE", uint256(0));
        uint256 toLanding = vm.envOr("TO_LANDING", uint256(0));

        uint256 landBefore = IERC20S(USDC).balanceOf(LANDING);

        vm.startBroadcast(pk);

        CrownEngineerIdle eng;
        if (seeder.code.length == 0) {
            eng = new CrownEngineerIdle(MORPHO, USDC, HOT, LANDING, MID);
            IMorphoAuth(MORPHO).setAuthorization(address(eng), true);
            console2.log("deployed", address(eng));
        } else {
            eng = CrownEngineerIdle(seeder);
            console2.log("reuse", address(eng));
        }

        if (fire == 1) {
            if (toLanding == 1) {
                // Close capital must already sit on hot (ASK USDC) — Morpho sees idle, loans to Landing.
                IERC20S(USDC).approve(address(eng), ask);
                eng.broadcastIdleLoanToLanding(ask);
            } else {
                eng.broadcastIdleLoan(ask);
            }
            console2.log("peakIdle", eng.lastPeakIdle());
            console2.log("loaned", eng.lastLoan());
        }

        vm.stopBroadcast();

        console2.log("Landing before", landBefore);
        console2.log("Landing after", IERC20S(USDC).balanceOf(LANDING));
    }
}
