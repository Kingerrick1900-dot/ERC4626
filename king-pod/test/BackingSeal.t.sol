// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownBackingScribe} from "../src/fleet/CrownBackingScribe.sol";

contract BackingSealFork is Test {
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

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
    }

    function test_phase1_seal_gusd_backed_engine_cold() public {
        CrownBackingScribe scribe = new CrownBackingScribe(
            MORPHO, EUSD, GUSD, RSS, HOT, MID_EUSD50, MID_GUSD50, MID_USDC, NOTES, FX
        );
        CrownBackingScribe.Seal memory s = scribe.seal();
        assertTrue(s.gusdFullyBacked, "gUSD not 1:1 eUSD float");
        assertTrue(s.notesCanIssue, "notes");
        assertTrue(s.freezeCold, "engine must be cold");
        assertTrue(s.sealOk, "seal");
        assertGe(s.usdcBorrowCapacity, 10_000_000e6, "cap");
        console2.log("eusdTotal", s.eusdTotal);
        console2.log("gusdTotal", s.gusdTotal);
        console2.log("usdcCapacity", s.usdcBorrowCapacity);
    }

    function test_phase2_rails_cold_checklist() public {
        CrownBackingScribe scribe = new CrownBackingScribe(
            MORPHO, EUSD, GUSD, RSS, HOT, MID_EUSD50, MID_GUSD50, MID_USDC, NOTES, FX
        );
        (bool notesOk, bool engineCold, bool capOk, bool ready) = scribe.railsCold();
        assertTrue(notesOk && engineCold && capOk && ready);
    }
}
