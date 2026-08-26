// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownSovereignAmo} from "../src/CrownSovereignAmo.sol";
import {CrownSovereignExit} from "../src/CrownSovereignExit.sol";

interface IERC20M {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoM {
    function setAuthorization(address, bool) external;
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}

/// @notice Phase F only: seed $50k AMO after 1200 book cleared.
contract FireMigrate50kSeed is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant GATE = 0xab2856626BBd8E6fba9dB93783029eB973E8427F;
    address constant ORACLE50 = 0x264f7AfB8f12028345B87FD5E58F2CF444EebA90;
    bytes32 constant MID50 = 0x6075ba260df7fd5ad5bc9f1de33ac0bc2d8201dbe44b0081e89d9974f179867b;
    uint256 constant LLTV = 770000000000000000;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_MIGRATE", uint256(0)) == 1, "NEED FIRE");

        uint256 hotPk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(hotPk) == HOT, "NOT_HOT");
        uint256 landPk = vm.envOr("LANDING_PRIVATE_KEY", hotPk);

        uint256 landEusd = IERC20M(EUSD).balanceOf(LANDING);
        uint256 rss = IERC20M(RSS).balanceOf(HOT);
        console2.log("landEusd", landEusd);
        console2.log("hotRss", rss);
        require(landEusd > 0 && rss > 0, "NOT_READY");

        vm.startBroadcast(hotPk);
        CrownSovereignAmo amo50 = new CrownSovereignAmo(
            MORPHO, EUSD, RSS, GATE, HOT, LANDING, MID50, ORACLE50, IRM, LLTV, LANDING
        );
        CrownSovereignExit exit50 = new CrownSovereignExit(
            MORPHO, EUSD, RSS, HOT, LANDING, MID50, ORACLE50, IRM, LLTV, HOT
        );
        console2.log("amo50", address(amo50));
        console2.log("exit50", address(exit50));
        IMorphoM(MORPHO).setAuthorization(address(amo50), true);
        IMorphoM(MORPHO).setAuthorization(address(exit50), true);
        IERC20M(RSS).approve(address(amo50), type(uint256).max);
        vm.stopBroadcast();

        vm.startBroadcast(landPk);
        amo50.setRequireGate(false);
        IMorphoM(MORPHO).setAuthorization(address(exit50), true);
        IERC20M(EUSD).approve(address(amo50), landEusd);
        vm.stopBroadcast();

        vm.startBroadcast(hotPk);
        amo50.supplyAmo(LANDING, landEusd);
        console2.log("supplied50", landEusd);
        console2.log("idle50", amo50.idle());
        amo50.postCollateral(0);
        uint256 idle = amo50.idle();
        uint256 borrowAsk = idle * 90 / 100;
        amo50.borrowEusd(borrowAsk, HOT);
        console2.log("borrowed50", borrowAsk);
        vm.stopBroadcast();

        vm.startBroadcast(landPk);
        amo50.setRequireGate(true);
        vm.stopBroadcast();

        (, uint128 b50, uint128 c50) = IMorphoM(MORPHO).position(MID50, HOT);
        (uint256 s50,,) = IMorphoM(MORPHO).position(MID50, LANDING);
        console2.log("supShares50", s50);
        console2.log("borShares50", uint256(b50));
        console2.log("coll50", uint256(c50));
        console2.log("hotEusd", IERC20M(EUSD).balanceOf(HOT));
        console2.log("idleFinal", amo50.idle());
        console2.log("MIGRATE_50K_OK", uint256(1));
    }
}
