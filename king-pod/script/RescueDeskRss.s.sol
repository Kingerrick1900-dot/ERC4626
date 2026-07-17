// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IDeskRescue {
    function rescue(address token, uint256 amt, address to) external;
    function claimRss() external;
}

interface IERC20B {
    function balanceOf(address) external view returns (uint256);
}

/// @notice Unit B — pull RSS off KingSeedDesk back to King hot.
contract RescueDeskRss is Script {
    address constant DESK = 0xF43B75B686e3Faa2C7FD4ac9a041b6316C63e8DF;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant KING = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        uint256 bal = IERC20B(RSS).balanceOf(DESK);
        console2.log("deskRss", bal);
        require(bal > 0, "EMPTY");

        vm.startBroadcast(pk);
        // claim any seeder share first (may revert if none — ignore via try in shell)
        IDeskRescue(DESK).rescue(RSS, bal, KING);
        vm.stopBroadcast();

        console2.log("kingRssAfter", IERC20B(RSS).balanceOf(KING));
    }
}
