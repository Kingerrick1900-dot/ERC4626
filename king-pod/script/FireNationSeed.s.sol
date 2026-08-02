// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownNationSeed} from "../src/CrownNationSeed.sol";

interface IERC20N {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice KING_GO=1 FIRE_NATION_SEED=1 — deploy seed cannon (default 70% ops / 30% yELE).
/// @dev Optional SELF_SEED_USDC micros from hot into seedOps to prove the pipe (careful — burns ops dust).
contract FireNationSeed is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant COMPLETER = 0x12514e1f999131eA78D402a7258b67A65F9342Ff;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_NATION_SEED", uint256(0)) == 1, "NEED FIRE_NATION_SEED=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        uint16 bps = uint16(vm.envOr("COMPLETE_BPS", uint256(7000))); // 70% Landing / 30% yELE
        uint256 selfSeed = vm.envOr("SELF_SEED_USDC", uint256(0));

        console2.log("hotUsdcBefore", IERC20N(USDC).balanceOf(HOT));

        CrownNationSeed seed = CrownNationSeed(vm.envOr("NATION_SEED", address(0)));

        vm.startBroadcast(pk);
        if (address(seed) == address(0) || address(seed).code.length == 0) {
            seed = new CrownNationSeed(HOT, COMPLETER, YELE, USDC, bps);
            console2.log("deployedNationSeed", address(seed));
        }

        if (selfSeed > 0) {
            require(IERC20N(USDC).balanceOf(HOT) >= selfSeed, "USDC");
            require(IERC20N(USDC).approve(address(seed), selfSeed), "APP");
            seed.seedOps(selfSeed);
            console2.log("selfSeedOps", selfSeed);
        }
        vm.stopBroadcast();

        console2.log("NATION_SEED", address(seed));
        console2.log("completeBps", uint256(seed.completeBps()));
        console2.log("maxAsk", seed.maxAsk());
        console2.log("hotUsdcAfter", IERC20N(USDC).balanceOf(HOT));
        console2.log("NATION_SEED_OK", uint256(1));
    }
}
