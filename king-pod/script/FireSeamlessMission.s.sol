// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownSeamlessMission} from "../src/CrownSeamlessMission.sol";

interface IMorphoAuth {
    function setAuthorization(address, bool) external;
}

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice Fire Seamless-shaped close. Zero hot USDC buffer.
/// Env:
///   FIRE=1
///   ASK (default 700_000e6)
///   EQUITY_RSS (default 0 — optional; King already holds ~9.76M free)
///   WANT_LANDING (default 0 — surplus only when idle allows)
///   MACHINE (reuse deployed CrownSeamlessMission)
contract FireSeamlessMission is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant MID = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    function run() external {
        uint256 ask = vm.envOr("ASK", uint256(700_000e6));
        uint256 equity = vm.envOr("EQUITY_RSS", uint256(0));
        uint256 want = vm.envOr("WANT_LANDING", uint256(0));
        bool fire = vm.envOr("FIRE", false);

        uint256 landBefore = IERC20F(USDC).balanceOf(LANDING);
        console2.log("Landing USDC before", landBefore);
        console2.log("ask", ask);
        console2.log("equityRss", equity);
        console2.log("wantLanding", want);

        vm.startBroadcast();
        CrownSeamlessMission c;
        address existing = vm.envOr("MACHINE", address(0));
        if (existing == address(0)) {
            c = new CrownSeamlessMission(MORPHO, USDC, RSS, HOT, LANDING, MID);
            IMorphoAuth(MORPHO).setAuthorization(address(c), true);
            console2.log("deployed", address(c));
        } else {
            c = CrownSeamlessMission(existing);
            console2.log("reuse", existing);
        }

        if (equity > 0) {
            IERC20F(RSS).approve(address(c), equity);
        }

        if (fire) {
            if (want > 0) {
                c.seamlessLand(ask, want, equity);
            } else {
                c.seamlessClose(ask, equity);
            }
            console2.log("closed", c.lastClosed());
            console2.log("peakIdle", c.lastPeakIdle());
            console2.log("surplusToLanding", c.lastSurplusToLanding());
        }
        vm.stopBroadcast();

        console2.log("Landing USDC after", IERC20F(USDC).balanceOf(LANDING));
        console2.log("Landing delta", IERC20F(USDC).balanceOf(LANDING) - landBefore);
    }
}
