// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownUnwind} from "../src/CrownUnwind.sol";
import {IMorphoU} from "../src/CrownUnwind.sol";

contract DeployUnwind is Script {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant KING = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;

    function run() external {
        vm.startBroadcast();
        IMorphoU.MarketParams memory p = IMorphoU.MarketParams({
            loanToken: USDC,
            collateralToken: RSS,
            oracle: ORACLE,
            irm: IRM,
            lltv: 770000000000000000
        });
        CrownUnwind u = new CrownUnwind(MORPHO, USDC, RSS, KING, p, KING);
        console2.log("CrownUnwind", address(u));
        vm.stopBroadcast();
    }
}
