// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {MorphoFixedOracle} from "../src/MorphoFixedOracle.sol";
import {MorphoKingDesk} from "../src/MorphoKingDesk.sol";

contract DeployMorphoDesk is Script {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant KING = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    uint256 constant LLTV = 770000000000000000; // 77%
    // $0.05 → Morpho price 5e22
    uint256 constant PRICE = 5e22;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        MorphoFixedOracle oracle = new MorphoFixedOracle(PRICE);
        MorphoKingDesk desk = new MorphoKingDesk(MORPHO, USDC, RSS, IRM, LLTV, KING, KING);
        desk.create(address(oracle));
        oracle.transferOwnership(KING);

        console2.log("oracle", address(oracle));
        console2.log("desk", address(desk));
        console2.log("marketId");
        console2.logBytes32(desk.marketId());

        vm.stopBroadcast();
    }
}
