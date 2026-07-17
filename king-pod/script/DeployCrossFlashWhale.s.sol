// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownCrossFlash} from "../src/CrownCrossFlash.sol";
import {MorphoEliteOracle} from "../src/MorphoEliteOracle.sol";

interface IMorphoAuth {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
}

contract DeployCrossFlashWhale is Script {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant KING = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant VAULT = 0xA1aFcb46a64C9173519180458C1cF302179c832a;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        MorphoEliteOracle elite = new MorphoEliteOracle(1e24); // start $1, uncapped
        elite.transferOwnership(KING);

        CrownCrossFlash whale = new CrownCrossFlash(
            MORPHO, USDC, KING, VAULT, MARKET_ID, USDC, RSS, ORACLE, IRM, LLTV, KING
        );
        IMorphoAuth(MORPHO).setAuthorization(address(whale), true);

        vm.stopBroadcast();
        console2.log("MorphoEliteOracle", address(elite));
        console2.log("CrownCrossFlash", address(whale));
    }
}
