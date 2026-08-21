// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownTakeWethIdle} from "../src/CrownTakeWethIdle.sol";

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoAuth {
    function setAuthorization(address, bool) external;
}

/// @notice Deploy / arm permissionless TAKE of WETH/USDC idle → Landing.
/// FIRE=1 broadcasts. Optional POKE=1 if equity already on hot.
contract FireTakeWethIdle is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant WETH_MID = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;

    function run() external {
        bool fire = vm.envOr("FIRE", false);
        bool doPoke = vm.envOr("POKE", false);
        uint256 ask = vm.envOr("ASK_USDC", uint256(700_000e6));
        // ~380 WETH leaves oracle headroom vs $700k @ 86% LLTV (360 is razor-thin).
        uint256 minWeth = vm.envOr("MIN_WETH", uint256(380 ether));
        address existing = vm.envOr("TAKE", address(0));

        console2.log("hot WETH", IERC20F(WETH).balanceOf(HOT));
        console2.log("Landing USDC", IERC20F(USDC).balanceOf(LANDING));

        vm.startBroadcast();
        CrownTakeWethIdle take = CrownTakeWethIdle(payable(existing));
        if (address(take) == address(0)) {
            take = new CrownTakeWethIdle(MORPHO, USDC, WETH, HOT, LANDING, WETH_MID, HOT, minWeth, ask);
            IMorphoAuth(MORPHO).setAuthorization(address(take), true);
            // Equity source (hot) must allow TAKE to pull WETH on poke
            IERC20F(WETH).approve(address(take), type(uint256).max);
            console2.log("take", address(take));
        }

        if (fire && doPoke) {
            uint256 landBefore = IERC20F(USDC).balanceOf(LANDING);
            take.poke();
            uint256 delta = IERC20F(USDC).balanceOf(LANDING) - landBefore;
            console2.log("Landing delta", delta);
            require(delta >= ask, "LANDING_DID_NOT_HIT");
        }
        vm.stopBroadcast();

        console2.log("ready", take.ready());
        console2.log("idle", take.idle());
        console2.log("POKE anyone when ready()==true");
    }
}
