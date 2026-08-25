// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownSovereignExit} from "../src/CrownSovereignExit.sol";

interface IERC20E {
    function balanceOf(address) external view returns (uint256);
}

interface IMorphoAuthE {
    function setAuthorization(address, bool) external;
}

interface IMorphoPosE {
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}

/// @notice Fire full sovereign AMO exit. Env: EXIT=, MARKET_ID=, MORPHO=, EUSD=, RSS=, ORACLE=, IRM=, LLTV=
contract FireSovereignExit is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;

    function run() external {
        address exitAddr = vm.envOr("EXIT", address(0));
        bytes32 mid = vm.envBytes32("MARKET_ID");
        address oracle = vm.envAddress("ORACLE");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        CrownSovereignExit exiter;
        if (exitAddr == address(0)) {
            exiter = new CrownSovereignExit(MORPHO, EUSD, RSS, HOT, LANDING, mid, oracle, IRM, LLTV, HOT);
            console2.log("exit deployed", address(exiter));
        } else {
            exiter = CrownSovereignExit(exitAddr);
        }

        IMorphoAuthE(MORPHO).setAuthorization(address(exiter), true);
        vm.stopBroadcast();

        uint256 landingPk = vm.envOr("LANDING_PRIVATE_KEY", pk);
        if (landingPk != pk) {
            vm.startBroadcast(landingPk);
            IMorphoAuthE(MORPHO).setAuthorization(address(exiter), true);
            vm.stopBroadcast();
        }

        vm.startBroadcast(pk);
        uint256 eusdBefore = IERC20E(EUSD).balanceOf(HOT);
        uint256 rssBefore = IERC20E(RSS).balanceOf(HOT);
        uint256 landBefore = IERC20E(EUSD).balanceOf(LANDING);

        exiter.exitFull();

        console2.log("repaid", exiter.lastRepaid());
        console2.log("supply to landing", exiter.lastSupplyOut());
        console2.log("rss to king", exiter.lastRssOut());
        console2.log("hot eUSD delta", IERC20E(EUSD).balanceOf(HOT) - eusdBefore);
        console2.log("hot RSS delta", IERC20E(RSS).balanceOf(HOT) - rssBefore);
        console2.log("landing eUSD delta", IERC20E(EUSD).balanceOf(LANDING) - landBefore);

        (, uint128 bor, uint128 coll) = IMorphoPosE(MORPHO).position(mid, HOT);
        (uint256 sup,,) = IMorphoPosE(MORPHO).position(mid, LANDING);
        console2.log("dust bor", bor);
        console2.log("dust coll", coll);
        console2.log("dust sup shares", sup);

        vm.stopBroadcast();
    }
}
