// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownForceDeallocateLand} from "../src/CrownForceDeallocateLand.sol";

/// @notice Penalty already 0 on live V2. FIRE=1 → flash → forceDeallocate → Landing.
/// ASK default 700_000e6. RSS_COLL default 2_000_000e18 (cushion vs 77% LLTV).
/// Reverts unless Landing USDC increases by ASK.
contract FireForceDeallocateLand is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant VAULT = 0xB96BcfFBB458581a3AF7fEd3150B7CD4b233A7b9;
    address constant ADAPTER = 0x3088de5b1629C518382a55e307b1bD45f3BFEE8c;
    bytes32 constant MID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    function run() external {
        bool fire = vm.envOr("FIRE", false);
        uint256 ask = vm.envOr("ASK", uint256(700_000e6));
        uint256 rssColl = vm.envOr("RSS_COLL", uint256(2_000_000e18));

        uint256 landBefore = IERC20(USDC).balanceOf(LANDING);
        uint256 penalty = IVaultV2(VAULT).forceDeallocatePenalty(ADAPTER);
        console2.log("penalty", penalty);
        console2.log("Landing before", landBefore);
        console2.log("hot RSS", IERC20(RSS).balanceOf(HOT));
        console2.log("ask", ask);
        console2.log("rssColl", rssColl);
        require(penalty == 0, "PENALTY_NOT_0");

        if (fire && ask == 0) revert("NO_FIRE_WITHOUT_ASK");

        vm.startBroadcast();
        CrownForceDeallocateLand ex;
        address existing = vm.envOr("MACHINE", address(0));
        if (existing == address(0)) {
            ex = new CrownForceDeallocateLand(MORPHO, USDC, RSS, VAULT, ADAPTER, LANDING, HOT, MID);
            console2.log("deployed", address(ex));
        } else {
            ex = CrownForceDeallocateLand(existing);
        }

        if (fire) {
            IERC20(RSS).approve(address(ex), rssColl);
            ex.fire(ask, rssColl);
            uint256 delta = IERC20(USDC).balanceOf(LANDING) - landBefore;
            console2.log("Landing after", IERC20(USDC).balanceOf(LANDING));
            console2.log("Landing delta", delta);
            console2.log("lastClosed", ex.lastClosed());
            require(delta >= ask, "LANDING_DID_NOT_HIT");
        }
        vm.stopBroadcast();
    }
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IVaultV2 {
    function forceDeallocatePenalty(address) external view returns (uint256);
}
