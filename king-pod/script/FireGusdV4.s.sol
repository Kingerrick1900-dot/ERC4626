// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownGoldUsd} from "../src/CrownGoldUsd.sol";
import {CrownSyncRedeem8020} from "../src/stack/CrownSyncRedeem8020.sol";

/// @notice Deploy gUSD brand layer + 8020 sync redeem on Base.
/// KING_GO=1 FIRE_GUSD=1 forge script … --rpc-url $BASE_RPC_URL --broadcast
contract FireGusdV4 is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    // Base multi-PSM (may have 0 reserve — 8020 reverts honestly until seeded)
    address constant BASE_PSM = 0xF7337A26d9456e42a36531A12036A4556EF1F987;
    // Base ELE77 PoR as interim gold-narrative feed until Scroll gold PoR is mirrored
    address constant BASE_POR = 0x3640f1CC913B772EA4D9BDF96a67196590058379;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_GUSD", uint256(0)) == 1, "NEED FIRE_GUSD=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);
        CrownGoldUsd gusd = new CrownGoldUsd(EUSD, BASE_POR, HOT);
        console2.log("gUSD", address(gusd));
        console2.log("goldBackingUsd", gusd.goldBackingUsd());

        CrownSyncRedeem8020 sync = new CrownSyncRedeem8020(EUSD, address(gusd), BASE_PSM, USDC, HOT);
        console2.log("sync8020", address(sync));
        console2.log("maxRedeemSync", sync.maxRedeemSync(HOT));
        vm.stopBroadcast();

        console2.log("GUSD_V4_OK", uint256(1));
    }
}
