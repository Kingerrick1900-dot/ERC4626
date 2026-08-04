// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownRssGold} from "../src/CrownRssGold.sol";
import {CrownRssGoldWrap} from "../src/CrownRssGoldWrap.sol";
import {CrownRssGoldCdp} from "../src/CrownRssGoldCdp.sol";
import {CrownRssBoundReservesGate} from "../src/zk/CrownRssBoundReservesGate.sol";
import {MorphoFrozenFixedOracle} from "../src/MorphoFrozenFixedOracle.sol";

/// @notice Deploy RSS ← Elepan gold/reserves fork. DRY unless FIRE_RSS_GOLD_FORK=1.
/// @dev Does not mint, wrap, or touch Morpho loans. King GO required to broadcast.
contract FireRssElepanGoldFork is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;

    function run() external {
        bool fire = vm.envOr("FIRE_RSS_GOLD_FORK", uint256(0)) == 1;
        console2.log("=== RSS ELEPAN GOLD FORK ===");
        console2.log("rss", RSS);
        console2.log("eusd", EUSD);
        console2.log("fire", fire ? 1 : 0);

        if (!fire) {
            console2.log("DRY - set FIRE_RSS_GOLD_FORK=1 KING_OK=1 to deploy");
            return;
        }
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);

        CrownRssGold gold = new CrownRssGold(HOT);
        CrownRssGoldWrap wrap = new CrownRssGoldWrap(RSS, address(gold), HOT);
        gold.setMinter(address(wrap));

        MorphoFrozenFixedOracle oracle = new MorphoFrozenFixedOracle(1e24); // $1
        CrownRssGoldCdp cdp = new CrownRssGoldCdp(address(gold), EUSD, address(oracle), HOT, LANDING, HOT);
        CrownRssBoundReservesGate gate = new CrownRssBoundReservesGate(RSS, HOT);

        vm.stopBroadcast();

        console2.log("CrownRssGold", address(gold));
        console2.log("CrownRssGoldWrap", address(wrap));
        console2.log("Oracle$1", address(oracle));
        console2.log("CrownRssGoldCdp", address(cdp));
        console2.log("CrownRssBoundReservesGate", address(gate));
        console2.log("RSS_ELEPAN_GOLD_FORK_OK");
        console2.log("NOTE: eUSD minter must allow CDP before mintToLanding - separate King step");
    }
}
