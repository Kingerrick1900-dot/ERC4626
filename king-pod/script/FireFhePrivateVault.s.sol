// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownFhePrivateVault} from "../src/CrownFhePrivateVault.sol";

/// @notice Deploy FHE-ready private vault rail wired to Elepan ZK gate.
/// @dev KING_GO=1 FIRE_FHE=1
contract FireFhePrivateVault is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    address constant Y_ELEPAN_WETH = 0xfdD5a1d4823411809D6ac735991B3A015E5AaAb5;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_FHE", uint256(0)) == 1, "NEED FIRE_FHE=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        address gate = vm.envOr("GATE", GATE);
        address yVault = vm.envOr("YVAULT", Y_ELEPAN_WETH);

        vm.startBroadcast(pk);
        CrownFhePrivateVault v = new CrownFhePrivateVault(USDC, gate, HOT, HOT);
        // Note: yELEPAN-WETH is WETH asset — USDC→WETH allocate rail deferred; store pointer for ops.
        v.setYVault(yVault);
        vm.stopBroadcast();

        console2.log("CrownFhePrivateVault", address(v));
        console2.log("gate", gate);
        console2.log("yVault", yVault);
        console2.log("feeBps", v.performanceFeeBps());
    }
}
