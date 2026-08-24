// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownSovereignAmo} from "../src/CrownSovereignAmo.sol";
import {CrownDepthAttest} from "../src/CrownDepthAttest.sol";

interface IBoundGateAct {
    function isProven(address) external view returns (bool);
    function minThreshold() external view returns (uint256);
}

interface IFlashPackAct {
    function fireLive(uint256 amount) external returns (bool proven, uint256 landingDelta);
}

/// @notice Complete sovereign activation: pack refresh → re-arm gate → scribe snap.
/// Env: POOL=0xe87e7e4… REFRESH=1 REARM=1 SNAP=1
contract FireSovereignActivation is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant AMO = 0x151C947B813400fE78EE176843F2d666c07422eA;
    address constant SCRIBE = 0xFAE5a8065d81c308395E050d737fA7a5b2b23160;
    address constant FLASH_PACK = 0x22C07d684ca8D5963A94e17C8e78B9e6105f34F4;
    address constant GATE = 0xab2856626BBd8E6fba9dB93783029eB973E8427F;

    function run() external {
        CrownSovereignAmo amo = CrownSovereignAmo(AMO);
        IFlashPackAct flashPack = IFlashPackAct(FLASH_PACK);
        IBoundGateAct gate = IBoundGateAct(GATE);

        uint256 hotPk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(hotPk) == HOT, "NOT_HOT");

        if (vm.envOr("REFRESH", uint256(0)) == 1) {
            vm.startBroadcast(hotPk);
            uint256 amt = gate.minThreshold();
            (bool proven,) = flashPack.fireLive(amt);
            console2.log("pack refresh proven", proven);
            require(proven, "PACK_REFRESH_FAIL");
            vm.stopBroadcast();
        }

        if (vm.envOr("REARM", uint256(0)) == 1) {
            require(gate.isProven(HOT), "PACK_NOT_PROVEN");
            uint256 landingPk = vm.envOr("LANDING_PRIVATE_KEY", hotPk);
            vm.startBroadcast(landingPk);
            amo.setRequireGate(true);
            console2.log("requireGate ON");
            vm.stopBroadcast();
        }

        if (vm.envOr("SNAP", uint256(0)) == 1) {
            vm.startBroadcast(hotPk);
            CrownDepthAttest(SCRIBE).snap();
            console2.log("scribe snapped");
            vm.stopBroadcast();
        }

        (uint256 idleEusd,,, bool provenAmo) = amo.book();
        console2.log("amo idle", idleEusd);
        console2.log("amo packReady", provenAmo);
        console2.log("requireGate", amo.requireGate());
        console2.log("MISSION sovereign activation complete");
    }
}
