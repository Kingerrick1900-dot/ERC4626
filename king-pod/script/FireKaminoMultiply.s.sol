// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownKaminoMultiply} from "../src/CrownKaminoMultiply.sol";

interface IMorphoAuth {
    function setAuthorization(address, bool) external;
}

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice Fire EXACT Kamino Multiply ONLY if Landing USDC will hit.
/// HARD LAW: FIRE=1 requires WANT_LANDING > 0 and post-tx Landing delta >= WANT.
/// Env: FIRE EQUITY_WETH FLASH WANT_LANDING MIN_WETH_OUT MACHINE
contract FireKaminoMultiply is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant AERO = 0xcDAC0d6c6C59727a65F871236188350531885C43;
    bytes32 constant MID = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;

    function run() external {
        bool fire = vm.envOr("FIRE", false);
        uint256 equity = vm.envOr("EQUITY_WETH", uint256(0));
        uint256 flash = vm.envOr("FLASH", uint256(700_000e6));
        uint256 want = vm.envOr("WANT_LANDING", uint256(700_000e6));
        uint256 minOut = vm.envOr("MIN_WETH_OUT", uint256(1));

        uint256 landBefore = IERC20F(USDC).balanceOf(LANDING);
        console2.log("Landing before", landBefore);
        console2.log("WETH on hot", IERC20F(WETH).balanceOf(HOT));

        // HARD LAW — never broadcast a fire that does not target Landing credit
        if (fire && want == 0) revert("NO_FIRE_WITHOUT_LANDING_WANT");

        vm.startBroadcast();
        CrownKaminoMultiply k;
        address existing = vm.envOr("MACHINE", address(0));
        if (existing == address(0)) {
            k = new CrownKaminoMultiply(MORPHO, USDC, WETH, AERO, HOT, LANDING, MID);
            IMorphoAuth(MORPHO).setAuthorization(address(k), true);
            console2.log("deployed", address(k));
        } else {
            k = CrownKaminoMultiply(existing);
        }

        if (fire) {
            if (equity > 0) IERC20F(WETH).approve(address(k), equity);
            k.multiply(equity, flash, want, minOut);
            // Contract already reverts on LandingMiss; double-check for scribe
            uint256 delta = IERC20F(USDC).balanceOf(LANDING) - landBefore;
            console2.log("Landing delta", delta);
            require(delta >= want, "LANDING_DID_NOT_HIT");
        }
        vm.stopBroadcast();
    }
}
