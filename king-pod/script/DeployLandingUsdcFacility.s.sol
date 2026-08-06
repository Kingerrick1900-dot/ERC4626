// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownLandingUsdcFacility} from "../src/CrownLandingUsdcFacility.sol";
import {CrownRssUsdcDesk} from "../src/CrownRssUsdcDesk.sol";

/// @notice Deploy the missing-piece USDC exit facility (+ optional RSS desk).
/// Env: PRIVATE_KEY. Optional DEPLOY_DESK=1.
contract DeployLandingUsdcFacility is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant PSM = 0xF7337A26d9456e42a36531A12036A4556EF1F987;
    address constant ORACLE = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);
        CrownLandingUsdcFacility fac =
            new CrownLandingUsdcFacility(USDC, EUSD, RSS, PSM, HOT, LANDING);
        address desk;
        if (vm.envOr("DEPLOY_DESK", uint256(0)) == 1) {
            desk = address(new CrownRssUsdcDesk(RSS, USDC, ORACLE, HOT, LANDING, 0.75e18));
        }
        vm.stopBroadcast();

        console2.log("FACILITY", address(fac));
        console2.log("DESK", desk);
        console2.log("LANDING", LANDING);
        console2.log("Rails: fundOtc/settleOtcEusd | fundDesk+desk.draw | seedPsm/redeemPsmToLanding");
    }
}
