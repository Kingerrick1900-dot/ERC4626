// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {KingSeedDesk} from "../src/KingSeedDesk.sol";
import {CrownEliteClose} from "../src/CrownEliteClose.sol";
import {IMorphoElite} from "../src/CrownEliteClose.sol";

/// @notice Deploy CrownSeedFill desk + CrownEliteClose. Fire eliteClose only after inventory + Morpho liquidity.
contract DeployEliteClose is Script {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000; // 77%
    uint256 constant PRICE = 50_000; // $0.05 / RSS

    address constant KING = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant CAKE = 0xA1aFcb46a64C9173519180458C1cF302179c832a;

    function run() external {
        vm.startBroadcast();

        KingSeedDesk desk = new KingSeedDesk(RSS, USDC, CAKE, PRICE, KING);
        console2.log("KingSeedDesk", address(desk));

        IMorphoElite.MarketParams memory params = IMorphoElite.MarketParams({
            loanToken: USDC,
            collateralToken: RSS,
            oracle: ORACLE,
            irm: IRM,
            lltv: LLTV
        });

        CrownEliteClose closer =
            new CrownEliteClose(MORPHO, USDC, RSS, address(desk), KING, CAKE, params, KING);
        console2.log("CrownEliteClose", address(closer));

        desk.setFiller(address(closer), true);
        console2.log("filler set");

        vm.stopBroadcast();
    }
}
