// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownSeedLand} from "../src/CrownSeedLand.sol";

interface IMorphoAuth {
    function setAuthorization(address, bool) external;
}

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice Fire seedLand: buffer want + flash F → supply → borrow F+want → Landing.
/// FIRE=1 required. Reverts if Landing misses or hot lacks USDC buffer.
contract FireSeedLand is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant MID = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    function run() external {
        bool fire = vm.envOr("FIRE", false);
        uint256 want = vm.envOr("WANT_LANDING", uint256(700_000e6));
        uint256 closeFlash = vm.envOr("CLOSE_FLASH", want);
        uint256 rssColl = vm.envOr("RSS_COLL", uint256(5_000e18));

        uint256 landBefore = IERC20F(USDC).balanceOf(LANDING);
        uint256 hotUsdc = IERC20F(USDC).balanceOf(HOT);
        console2.log("Landing before", landBefore);
        console2.log("hot USDC", hotUsdc);
        console2.log("hot RSS", IERC20F(RSS).balanceOf(HOT));
        console2.log("want", want);
        console2.log("closeFlash", closeFlash);
        console2.log("rssColl", rssColl);

        if (!fire) revert("NO_FIRE");
        if (want == 0) revert("NO_WANT");
        if (hotUsdc < want) revert("NO_BUFFER_USDC");

        vm.startBroadcast();
        CrownSeedLand gun;
        address existing = vm.envOr("MACHINE", address(0));
        if (existing == address(0)) {
            gun = new CrownSeedLand(MORPHO, USDC, RSS, HOT, LANDING, MID);
            IMorphoAuth(MORPHO).setAuthorization(address(gun), true);
            console2.log("deployed", address(gun));
        } else {
            gun = CrownSeedLand(existing);
        }

        IERC20F(RSS).approve(address(gun), rssColl);
        IERC20F(USDC).approve(address(gun), want);
        gun.seedLand(rssColl, want, closeFlash);

        uint256 delta = IERC20F(USDC).balanceOf(LANDING) - landBefore;
        console2.log("Landing after", IERC20F(USDC).balanceOf(LANDING));
        console2.log("Landing delta", delta);
        require(delta >= want, "LANDING_DID_NOT_HIT");
        vm.stopBroadcast();
    }
}
