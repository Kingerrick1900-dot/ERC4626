// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownElepanBills} from "../src/CrownElepanBills.sol";

interface IMorphoD {
    function setAuthorization(address, bool) external;
}

/// @dev KING_GO=1 FIRE_DEPLOY_BILLS=1 — deploy + morpho auth only
contract FireDeployElepanBills is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MID = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_DEPLOY_BILLS", uint256(0)) == 1, "NEED FIRE_DEPLOY_BILLS=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        vm.startBroadcast(pk);
        CrownElepanBills bills =
            new CrownElepanBills(MORPHO, USDC, ELE, YELE, HOT, LANDING, MID, ORACLE, IRM, LLTV, HOT);
        IMorphoD(MORPHO).setAuthorization(address(bills), true);
        vm.stopBroadcast();

        console2.log("BILLS", address(bills));
        console2.log("NEXT: transfer yELE Landing -> Hot, then FIRE_ELE_BILLS");
    }
}
