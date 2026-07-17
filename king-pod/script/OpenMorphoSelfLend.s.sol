// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "../src/lib/Core.sol";
import {MorphoKingDesk} from "../src/MorphoKingDesk.sol";

interface IMorphoAuth {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
}

/// @dev Open buffered self-lend: 20M RSS collateral, $500k USDC flash (HF buffer under 77% LLTV).
contract OpenMorphoSelfLend is Script {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant KING = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    uint256 constant RSS_AMT = 20_000_000 ether;
    uint256 constant FLASH = 500_000e6;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address desk = vm.envAddress("DESK");
        vm.startBroadcast(pk);

        // Desk must be authorized to borrow/repay/withdraw on behalf of King
        IMorphoAuth(MORPHO).setAuthorization(desk, true);
        IERC20(RSS).approve(desk, RSS_AMT);
        MorphoKingDesk(desk).openSelfLend(RSS_AMT, FLASH);

        uint256 hf = MorphoKingDesk(desk).healthFactor(KING);
        console2.log("opened HF", hf);

        vm.stopBroadcast();
    }
}
