// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownSovereignAmo} from "../src/CrownSovereignAmo.sol";
import {CrownDepthAttest} from "../src/CrownDepthAttest.sol";

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoAuth {
    function setAuthorization(address, bool) external;
}

/// @notice Fire sovereign AMO: 100M eUSD supply → post RSS → borrow eUSD.
/// Env: AMO=, SCRIBE=, SUPPLY_AMT (0=full Landing), POST_COLL=1, BORROW_AMT, SKIP_GATE=1
contract FireSovereignAmo is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    function run() external {
        address amoAddr = vm.envAddress("AMO");
        CrownSovereignAmo amo = CrownSovereignAmo(amoAddr);

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        if (vm.envOr("SKIP_GATE", uint256(0)) == 1) {
            amo.setRequireGate(false);
            console2.log("gate OFF");
        }

        uint256 supplyAmt = vm.envOr("SUPPLY_AMT", uint256(0));
        if (supplyAmt == 0) {
            supplyAmt = IERC20F(EUSD).balanceOf(LANDING);
        }
        console2.log("supplyAmt", supplyAmt);

        uint256 landingPk = vm.envOr("LANDING_PRIVATE_KEY", pk);
        vm.stopBroadcast();
        vm.startBroadcast(landingPk);
        IERC20F(EUSD).approve(amoAddr, supplyAmt);
        vm.stopBroadcast();
        vm.startBroadcast(pk);

        amo.supplyAmo(LANDING, supplyAmt);

        (uint256 idleEusd,,, bool proven) = amo.book();
        console2.log("idle after supply", idleEusd);
        console2.log("proven", proven);

        if (vm.envOr("POST_COLL", uint256(0)) == 1) {
            uint256 rssAmt = vm.envOr("RSS_AMT", uint256(0));
            IERC20F(RSS).approve(amoAddr, type(uint256).max);
            if (rssAmt == 0) {
                amo.postCollateral(0);
            } else {
                amo.postCollateral(rssAmt);
            }
            IMorphoAuth(MORPHO).setAuthorization(amoAddr, true);
        }

        uint256 borrowAmt = vm.envOr("BORROW_AMT", uint256(0));
        if (borrowAmt > 0) {
            amo.borrowEusd(borrowAmt, HOT);
            console2.log("borrowed", borrowAmt);
        }

        address scribeAddr = vm.envOr("SCRIBE", address(0));
        if (scribeAddr != address(0)) {
            CrownDepthAttest(scribeAddr).snap();
        }

        vm.stopBroadcast();

        console2.log("MISSION sovereign eUSD AMO fired");
    }
}
