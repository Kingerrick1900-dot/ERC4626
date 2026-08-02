// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownBaseEusdLink} from "../src/CrownBaseEusdLink.sol";

/// @notice Deploy Base eUSD link (lock for Scroll mint). KING_GO=1 FIRE_BASE_LINK=1
contract FireBaseEusdLink is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_BASE_LINK", uint256(0)) == 1, "NEED FIRE_BASE_LINK=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        vm.startBroadcast(pk);
        CrownBaseEusdLink link = new CrownBaseEusdLink(EUSD, LAND, HOT);
        vm.stopBroadcast();

        console2.log("baseLink", address(link));
        console2.log("BASE_EUSD_LINK_OK", uint256(1));
    }
}
