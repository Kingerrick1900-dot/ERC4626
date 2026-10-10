// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IOwnableF {
    function owner() external view returns (address);
    function transferOwnership(address) external;
}

/// @notice FIRE_FALCON_KING_SIGN=1 · ZK_SHIELD=1 · HOT_KEY
/// @dev King signs Falcon: HOT crowns Kingdom Safe as owner of the live Falcon stack.
contract FireFalconKingSign is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;

    address constant ORACLE = 0xF98bfd64D04752aD39fFD404959db4A9Aa98086A;
    address constant KRT = 0xBFcEB59591e73eB589eEf767E2151a5c62175AB7;
    address constant GUSD = 0x69A9247457f31bF367C300e00D6fBA81da7cbBE6;
    address constant HARVESTER = 0xeDDb1bfDbF2d5A0a619C99Dcd1AF9E9A88627871;
    address constant CROWN369 = 0xD75d8F6F10bfcF7cb52ed98a30e2A21a614c2925;

    function run() external {
        require(vm.envOr("FIRE_FALCON_KING_SIGN", uint256(0)) == 1, "FIRE_FALCON_KING_SIGN");
        require(vm.envOr("ZK_SHIELD", uint256(0)) == 1, "ZK_SHIELD");
        uint256 pk = vm.envUint("HOT_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        address[5] memory stack = [ORACLE, KRT, GUSD, HARVESTER, CROWN369];
        for (uint256 i; i < stack.length; i++) {
            require(IOwnableF(stack[i]).owner() == HOT, "NOT_HOT_OWNER");
        }

        vm.startBroadcast(pk);
        for (uint256 i; i < stack.length; i++) {
            IOwnableF(stack[i]).transferOwnership(SAFE);
        }
        vm.stopBroadcast();

        for (uint256 i; i < stack.length; i++) {
            require(IOwnableF(stack[i]).owner() == SAFE, "SAFE_NOT_OWNER");
            console2.log("OWNED_BY_SAFE", stack[i]);
        }
        console2.log("MISSION falcon king-signed - Safe owns stack - HOT remains Morpho supplier ops");
    }
}
