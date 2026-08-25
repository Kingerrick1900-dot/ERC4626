// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownFxEngine} from "../src/fleet/CrownFxEngine.sol";
import {CrownSyncRedeem8020} from "../src/stack/CrownSyncRedeem8020.sol";

/// @notice Deploy FxEngine + capacity 8020. Does NOT arm. Does NOT take loans.
/// KING_GO=1 FIRE_FX_DEPLOY=1
contract FireFxEngineDeploy is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant GUSD = 0x319A49BB274A826F889C6e7221FA82f24ac8bc5d;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant PSM = 0xF7337A26d9456e42a36531A12036A4556EF1F987;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant MID_USDC = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;
    address constant NOTES = 0xD432543C3ef51214c2BD4D79B4a387e2f900e1d3;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_FX_DEPLOY", uint256(0)) == 1, "NEED FIRE_FX_DEPLOY=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);

        CrownFxEngine engine = new CrownFxEngine(MORPHO, USDC, EUSD, HOT, MID_USDC, HOT);
        // armed stays false — no loans
        console2.log("fxEngine", address(engine));
        console2.log("armed", engine.armed());
        console2.log("idleUsdc", engine.idleUsdc());
        console2.log("borrowCapacity", engine.borrowCapacity());
        console2.log("canFill1M", engine.canFill(1_000_000e6));

        CrownSyncRedeem8020 sync = new CrownSyncRedeem8020(EUSD, GUSD, PSM, USDC, HOT);
        sync.wireCapacity(MORPHO, MID_USDC, HOT);
        sync.setFxEngine(address(engine));
        engine.setFiller(address(sync));
        console2.log("sync8020Fx", address(sync));
        console2.log("maxRedeemSync", sync.maxRedeemSync(HOT));

        vm.stopBroadcast();

        console2.log("notesCanIssue", NoteR(NOTES).canIssue());
        console2.log("FX_ENGINE_DEPLOYED_DISARMED", uint256(1));
    }
}

interface NoteR {
    function canIssue() external view returns (bool);
}
