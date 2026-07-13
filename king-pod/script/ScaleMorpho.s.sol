// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "../src/lib/Core.sol";
import {MorphoKingDesk} from "../src/MorphoKingDesk.sol";
interface IMorphoAuth { function setAuthorization(address authorized, bool newIsAuthorized) external; }
contract ScaleMorpho is Script {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant KING = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant DESK = 0x831b86E9AA185088CB095748bFBeF53F0D312472;
    uint256 constant RSS_AMT = 500_000 ether; // keep 500k liquid
    uint256 constant FLASH = 12_500e6;        // buffered under 77% of $25k
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        // Authorization already set from first open — do not call setAuthorization again.
        IERC20(RSS).approve(DESK, RSS_AMT);
        MorphoKingDesk(DESK).openSelfLend(RSS_AMT, FLASH);
        console2.log("HF", MorphoKingDesk(DESK).healthFactor(KING));
        vm.stopBroadcast();
    }
}
