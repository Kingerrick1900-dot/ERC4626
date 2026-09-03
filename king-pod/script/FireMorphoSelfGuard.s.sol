// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownMorphoSelfGuard} from "../src/prime/CrownMorphoSelfGuard.sol";

interface IMorphoAuthG {
    function setAuthorization(address authorized, bool newAuthorized) external;
}

interface IBorrowRouterG {
    function armed() external view returns (bool);
    function setArmed(bool) external;
}

/// @notice Deploy self-guard + Morpho-auth. No multisig. No flash.
/// @dev KING_GO=1 FIRE_SELF_GUARD=1 forge script script/FireMorphoSelfGuard.s.sol:FireMorphoSelfGuard --broadcast --slow
contract FireMorphoSelfGuard is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ROUTER = 0xBb3C372D4A0C398b6107f13ea4b1AB00B2b0A7aC;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        require(vm.envOr("FIRE_SELF_GUARD", uint256(0)) == 1, "NO_FIRE");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        CrownMorphoSelfGuard guard = new CrownMorphoSelfGuard(MORPHO, HOT, HOT);
        IMorphoAuthG(MORPHO).setAuthorization(address(guard), true);

        if (IBorrowRouterG(ROUTER).armed()) {
            IBorrowRouterG(ROUTER).setArmed(false);
        }

        vm.stopBroadcast();
        console2.log("SELF_GUARD", address(guard));
        console2.log("routerArmed", IBorrowRouterG(ROUTER).armed());
    }
}
