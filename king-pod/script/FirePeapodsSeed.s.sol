// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownPeapodsMorphoSeed} from "../src/CrownPeapodsMorphoSeed.sol";

interface IMorphoS {
    function setAuthorization(address, bool) external;
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

/// @notice Live Peapods self-lend seed. Env: PRIVATE_KEY, SEED_USDC (6dp, default 700_000e6).
contract FirePeapodsSeed is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    bytes32 constant MID = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");
        uint256 seedAmt = vm.envOr("SEED_USDC", uint256(700_000e6));

        (uint128 s0,, uint128 b0,,,) = IMorphoS(MORPHO).market(MID);

        vm.startBroadcast(pk);
        CrownPeapodsMorphoSeed seeder = new CrownPeapodsMorphoSeed(MORPHO, USDC, HOT, MID);
        IMorphoS(MORPHO).setAuthorization(address(seeder), true);
        seeder.seed(seedAmt);
        vm.stopBroadcast();

        (uint128 s1,, uint128 b1,,,) = IMorphoS(MORPHO).market(MID);
        console2.log("SEEDER", address(seeder));
        console2.log("SUPPLY_BEFORE", uint256(s0));
        console2.log("SUPPLY_AFTER", uint256(s1));
        console2.log("BORROW_BEFORE", uint256(b0));
        console2.log("BORROW_AFTER", uint256(b1));
        console2.log("ENGINEERED", uint256(s1) - uint256(s0));
    }
}
