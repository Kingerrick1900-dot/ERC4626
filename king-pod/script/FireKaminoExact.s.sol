// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownKaminoExact} from "../src/CrownKaminoExact.sol";

interface IMorphoAuth {
    function setAuthorization(address, bool) external;
}

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice Fire EXACT Kamino (free RSS equity). No WETH.
/// FIRE=1 only when WANT_LANDING > 0; reverts if Landing misses.
contract FireKaminoExact is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant AERO = 0x2C4F14744B8b3D087b768D0764d983Acb46d537a;
    bytes32 constant MID = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    function run() external {
        bool fire = vm.envOr("FIRE", false);
        uint256 equity = vm.envOr("EQUITY_RSS", uint256(10_000e18));
        uint256 flash = vm.envOr("FLASH", uint256(500_000e6));
        uint256 want = vm.envOr("WANT_LANDING", uint256(700_000e6));
        uint256 minOut = vm.envOr("MIN_RSS_OUT", uint256(1));

        uint256 landBefore = IERC20F(USDC).balanceOf(LANDING);
        console2.log("Landing before", landBefore);
        console2.log("free RSS", IERC20F(RSS).balanceOf(HOT));
        console2.log("market idle check via multiply");

        if (fire && want == 0) revert("NO_FIRE_WITHOUT_LANDING_WANT");

        vm.startBroadcast();
        CrownKaminoExact k;
        address existing = vm.envOr("MACHINE", address(0));
        if (existing == address(0)) {
            k = new CrownKaminoExact(MORPHO, USDC, RSS, AERO, HOT, LANDING, MID);
            IMorphoAuth(MORPHO).setAuthorization(address(k), true);
            console2.log("deployed", address(k));
        } else {
            k = CrownKaminoExact(existing);
        }
        if (fire) {
            if (equity > 0) IERC20F(RSS).approve(address(k), equity);
            k.multiply(equity, flash, want, minOut);
            uint256 delta = IERC20F(USDC).balanceOf(LANDING) - landBefore;
            console2.log("Landing delta", delta);
            require(delta >= want, "LANDING_DID_NOT_HIT");
        }
        vm.stopBroadcast();
    }
}
