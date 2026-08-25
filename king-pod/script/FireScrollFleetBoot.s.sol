// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MorphoRssOracle} from "../src/MorphoRssOracle.sol";
import {CrownScrollRss} from "../src/fleet/CrownFleetRails.sol";

/// @notice Scroll fleet boot — 2 txs: RSS + $50k oracle clone. Morpho Blue not yet on Scroll;
///         books auto-fire when Morpho+IRM land. Base prints in parallel.
/// KING_GO=1 FIRE_SCROLL_BOOT=1 SCROLL_PRIVATE_KEY=…
contract FireScrollFleetBoot is Script {
    address constant SCROLL_HOT = 0xca76AE9e29a5F01465D890dc30109cD58B78F864;
    uint256 constant GENESIS_RSS = 21_000_000_000 ether; // 21B like Base

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_SCROLL_BOOT", uint256(0)) == 1, "NEED FIRE_SCROLL_BOOT=1");
        uint256 pk = vm.envUint("SCROLL_PRIVATE_KEY");
        require(vm.addr(pk) == SCROLL_HOT, "SCROLL_HOT");

        vm.startBroadcast(pk);

        // Tx path 1: RSS on Scroll (new address — Base addr empty here)
        CrownScrollRss rss = new CrownScrollRss(SCROLL_HOT, SCROLL_HOT, GENESIS_RSS);
        console2.log("scrollRss", address(rss));
        console2.log("rssSupply", rss.totalSupply());
        console2.log("rssHot", rss.balanceOf(SCROLL_HOT));

        // Tx path 2: $50k oracle clone
        MorphoRssOracle oracle50 = new MorphoRssOracle(50_000);
        console2.log("scrollOracle50k", address(oracle50));
        console2.log("oraclePrice", oracle50.price());

        vm.stopBroadcast();

        // Honest gate: Morpho Blue CREATE2 not deployed on Scroll yet
        address morpho = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(morpho)
        }
        console2.log("morphoCodeSize", codeSize);
        if (codeSize == 0) {
            console2.log("SCROLL_MORPHO_PENDING", uint256(1));
            console2.log("BOOT_OK_WAIT_MORPHO_FOR_BOOKS", uint256(1));
        } else {
            console2.log("SCROLL_MORPHO_LIVE_FIRE_BOOKS_NEXT", uint256(1));
        }
        console2.log("SCROLL_FLEET_BOOT_OK", uint256(1));
    }
}
