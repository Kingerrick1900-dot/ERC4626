// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownVenusMultiply700k} from "../src/CrownVenusMultiply700k.sol";

interface IMorphoAuth {
    function setAuthorization(address, bool) external;
}

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice Fire Venus Multiply $700k with free RSS equity.
/// Env: FIRE=1  EQUITY_RSS (default 1000e18)  MACHINE  WANT_LANDING (default 0)
contract FireVenusMultiply700k is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant MID = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    function run() external {
        uint256 equity = vm.envOr("EQUITY_RSS", uint256(1_000e18));
        uint256 want = vm.envOr("WANT_LANDING", uint256(0));
        bool fire = vm.envOr("FIRE", false);

        uint256 landBefore = IERC20F(USDC).balanceOf(LANDING);
        console2.log("Landing before", landBefore);
        console2.log("free RSS", IERC20F(RSS).balanceOf(HOT));
        console2.log("equity", equity);

        vm.startBroadcast();
        CrownVenusMultiply700k m;
        address existing = vm.envOr("MACHINE", address(0));
        if (existing == address(0)) {
            m = new CrownVenusMultiply700k(MORPHO, USDC, RSS, HOT, LANDING, MID);
            IMorphoAuth(MORPHO).setAuthorization(address(m), true);
            console2.log("deployed", address(m));
        } else {
            m = CrownVenusMultiply700k(existing);
        }

        if (fire) {
            if (equity > 0) IERC20F(RSS).approve(address(m), equity);
            if (want > 0) m.multiplyLand700k(equity, want);
            else m.multiply700k(equity);
            console2.log("closed", m.lastClosed());
            console2.log("peakIdle", m.lastPeakIdle());
            console2.log("seedBorrow", m.lastSeedBorrow());
            console2.log("surplusLanding", m.lastSurplusToLanding());
        }
        vm.stopBroadcast();

        console2.log("Landing after", IERC20F(USDC).balanceOf(LANDING));
    }
}
