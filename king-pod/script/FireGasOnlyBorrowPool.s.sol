// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownGasOnlyBorrowPool} from "../src/CrownGasOnlyBorrowPool.sol";

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoAuth {
    function setAuthorization(address, bool) external;
}

/// @notice Deploy / fire gas-only borrow pool. FIRE=1 broadcasts. PARK=1 runs gasPark.
/// REFRESH=1 refreshes $1M pack. POKE=1 drains idle → Landing.
contract FireGasOnlyBorrowPool is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ORACLE = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant FLASH_PACK = 0x22C07d684ca8D5963A94e17C8e78B9e6105f34F4;
    address constant GATE = 0xab2856626BBd8E6fba9dB93783029eB973E8427F;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    bytes32 constant MID = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;
    uint256 constant LLTV = 770000000000000000;

    function run() external {
        bool fire = vm.envOr("FIRE", false);
        bool park = vm.envOr("PARK", false);
        bool refresh = vm.envOr("REFRESH", false);
        bool doPoke = vm.envOr("POKE", false);
        address existing = vm.envOr("POOL", address(0));
        uint256 usdcAmt = vm.envOr("USDC_AMT", uint256(1_000_000e6));
        uint256 rssColl = vm.envOr("RSS_COLL", uint256(0));

        CrownGasOnlyBorrowPool pool = CrownGasOnlyBorrowPool(existing);

        if (fire) {
            vm.startBroadcast();
            if (address(pool) == address(0)) {
                pool = new CrownGasOnlyBorrowPool(
                    MORPHO, USDC, RSS, YRSS, ORACLE, FLASH_PACK, GATE, PA, HOT, LANDING, MID, IRM, LLTV, HOT
                );
                console2.log("pool", address(pool));
                IMorphoAuth(MORPHO).setAuthorization(address(pool), true);
                IERC20F(RSS).approve(address(pool), type(uint256).max);
                // flash-bound subject must approve flash for pack refresh
                IERC20F(USDC).approve(FLASH_PACK, type(uint256).max);
            }
            if (refresh) {
                bool proven = pool.refreshPack(0);
                console2.log("pack proven", proven);
            }
            if (park) {
                pool.gasPark(rssColl, usdcAmt);
                console2.log("parked", pool.lastParkUsdc());
                console2.log("yrss shares", pool.lastParkShares());
            }
            if (doPoke) {
                uint256 d = pool.poke();
                console2.log("Landing delta", d);
            }
            vm.stopBroadcast();
        }

        if (address(pool) != address(0)) {
            (bool proven, uint256 idleU, uint256 yrssA, uint256 nav, uint256 land) = pool.book();
            console2.log("proven", proven);
            console2.log("idle", idleU);
            console2.log("yrssAssets", yrssA);
            console2.log("navRssUsd6", nav);
            console2.log("landingUsdc", land);
        }
        console2.log("MISSION: unmatched idle on RSS/1200 - borrow pool, not 700k ceiling");
    }
}
