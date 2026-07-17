// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownEliteFlashClose} from "../src/CrownEliteFlashClose.sol";
import {IMorphoFlashElite} from "../src/CrownEliteFlashClose.sol";

interface IDeskWire {
    function setFiller(address who, bool allowed) external;
}

/// @notice Deploy capital-halving closer; wire filler on live KingSeedDesk.
contract DeployEliteFlashClose is Script {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;

    address constant KING = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant CAKE = 0xA1aFcb46a64C9173519180458C1cF302179c832a;
    address constant DESK = 0xF43B75B686e3Faa2C7FD4ac9a041b6316C63e8DF;

    function run() external {
        vm.startBroadcast();

        IMorphoFlashElite.MarketParams memory params = IMorphoFlashElite.MarketParams({
            loanToken: USDC,
            collateralToken: RSS,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });

        CrownEliteFlashClose closer =
            new CrownEliteFlashClose(MORPHO, USDC, RSS, DESK, KING, CAKE, params, KING);
        console2.log("CrownEliteFlashClose", address(closer));

        IDeskWire(DESK).setFiller(address(closer), true);
        console2.log("filler wired on live desk");

        vm.stopBroadcast();
    }
}
