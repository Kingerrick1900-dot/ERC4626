// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownBackingScribe} from "../src/fleet/CrownBackingScribe.sol";

/// @notice Phase 1+2 NOW: deploy backing scribe, seal snap, print cold-rails checklist. No loans.
/// KING_GO=1 FIRE_SEAL=1
contract FireBackingSeal is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant GUSD = 0x319A49BB274A826F889C6e7221FA82f24ac8bc5d;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    bytes32 constant MID_EUSD50 = 0x6075ba260df7fd5ad5bc9f1de33ac0bc2d8201dbe44b0081e89d9974f179867b;
    bytes32 constant MID_GUSD50 = 0x5dd0f7c171f7de8899ca1025bfd9ee2fe2153762c532b691b1bdb344f46227cf;
    bytes32 constant MID_USDC = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;
    address constant NOTES = 0xD432543C3ef51214c2BD4D79B4a387e2f900e1d3;
    address constant FX = 0x821a54725370EB11155F25FD0A877540cA7D4099;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_SEAL", uint256(0)) == 1, "NEED FIRE_SEAL=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);
        CrownBackingScribe scribe = new CrownBackingScribe(
            MORPHO, EUSD, GUSD, RSS, HOT, MID_EUSD50, MID_GUSD50, MID_USDC, NOTES, FX
        );
        console2.log("scribe", address(scribe));

        CrownBackingScribe.Seal memory s = scribe.seal();
        vm.stopBroadcast();

        console2.log("eusdTotal", s.eusdTotal);
        console2.log("gusdTotal", s.gusdTotal);
        console2.log("gusdFloat", s.gusdEusdFloat);
        console2.log("hotGusd", s.hotGusd);
        console2.log("eusdIdle", s.eusdBookIdle);
        console2.log("gusdIdle", s.gusdBookIdle);
        console2.log("rssCollEusd", s.rssCollEusdBook);
        console2.log("rssCollGusd", s.rssCollGusdBook);
        console2.log("rssCollUsdc", s.rssCollUsdcBook);
        console2.log("usdcCapacity", s.usdcBorrowCapacity);
        console2.log("gusdFullyBacked", s.gusdFullyBacked);
        console2.log("notesCanIssue", s.notesCanIssue);
        console2.log("fxArmed", s.fxArmed);
        console2.log("freezeCold", s.freezeCold);
        console2.log("sealOk", s.sealOk);

        (bool notesOk, bool engineCold, bool capOk, bool ready) = scribe.railsCold();
        console2.log("rails notesOk", notesOk);
        console2.log("rails engineCold", engineCold);
        console2.log("rails capacityGe10m", capOk);
        console2.log("rails readyChecklist", ready);
        console2.log("BACKING_SEAL_OK", s.sealOk ? uint256(1) : uint256(0));
    }
}
