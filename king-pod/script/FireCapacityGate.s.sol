// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {NoteIssuerAuto} from "../src/fleet/CrownFleetRails.sol";
import {CrownSyncRedeem8020} from "../src/stack/CrownSyncRedeem8020.sol";
import {CrownBorrowCapacity} from "../src/fleet/CrownBorrowCapacity.sol";

/// @notice Deploy capacity-backed notes + wire 8020 maxRedeem to Morpho borrow headroom.
/// KING_GO=1 FIRE_CAPACITY=1
contract FireCapacityGate is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant PSM = 0xF7337A26d9456e42a36531A12036A4556EF1F987;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant GUSD = 0x319A49BB274A826F889C6e7221FA82f24ac8bc5d;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    // RSS/USDC/$1200 — USDC loan capacity vs King RSS
    bytes32 constant MID_USDC = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;
    address constant SYNC_LIVE = 0x0064532B41Ddd8961E6a6c528c70DB56efb13305;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_CAPACITY", uint256(0)) == 1, "NEED FIRE_CAPACITY=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 capNow = CrownBorrowCapacity.borrowCapacity(MORPHO, MID_USDC, HOT);
        console2.log("borrowCapacityUsdc", capNow);

        vm.startBroadcast(pk);

        NoteIssuerAuto notes = new NoteIssuerAuto(RSS, PSM, HOT, MORPHO, MID_USDC, HOT);
        notes.setArmed(true);
        console2.log("notesCapacity", address(notes));
        console2.log("notesBorrowCapacity", notes.borrowCapacity());
        console2.log("notesCanIssue", notes.canIssue());

        // Fresh 8020 with capacity wire (live sync may be prior bytecode without wireCapacity)
        CrownSyncRedeem8020 sync = new CrownSyncRedeem8020(EUSD, GUSD, PSM, USDC, HOT);
        sync.wireCapacity(MORPHO, MID_USDC, HOT);
        console2.log("sync8020Capacity", address(sync));
        console2.log("maxRedeemSync", sync.maxRedeemSync(HOT));
        console2.log("borrowCapacityUsdc8020", sync.borrowCapacityUsdc());

        vm.stopBroadcast();

        // Old live sync has no wireCapacity — expected false; new sync is the capacity rail
        (bool ok,) = SYNC_LIVE.call(abi.encodeWithSignature("wireCapacity(address,bytes32,address)", MORPHO, MID_USDC, HOT));
        console2.log("liveSyncWired", ok);
        console2.log("CAPACITY_GATE_OK", notes.canIssue() ? uint256(1) : uint256(0));
    }
}
