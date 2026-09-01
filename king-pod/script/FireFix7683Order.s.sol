// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownPrime7683Fill} from "../src/prime/CrownPrime7683Fill.sol";

/// @notice Cancel broken 7683 order (4500 USDC cap typo) and reopen at $4.5M max.
/// @dev KING_GO=1 FIRE_FIX_ORDER=1 OLD_ORDER_ID=0x… forge script …:FireFix7683Order --broadcast
contract FireFix7683Order is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant FILL = 0x4C021c77633e9441be218d2A27a4B40c1Bd720Ab;

    uint256 constant ORDER_EUSD = 5_000_000e18;
    /// @dev 4_500_000e6 = $4.5M USDC (6dp). Live typo used 4500000000 = $4,500 only.
    uint256 constant MAX_USDC_IN = 4_500_000e6;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO_GO");
        require(vm.envOr("FIRE_FIX_ORDER", uint256(0)) == 1, "NO_FIX");

        bytes32 oldId = vm.envBytes32("OLD_ORDER_ID");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);

        CrownPrime7683Fill(FILL).cancel(oldId);
        CrownPrime7683Fill(FILL).setFees(1000, 0);
        bytes32 newId = CrownPrime7683Fill(FILL).openOrder(HOT, ORDER_EUSD, MAX_USDC_IN, uint32(block.timestamp + 7 days));

        vm.stopBroadcast();
        console2.log("cancelled", vm.toString(oldId));
        console2.log("newOrderId", vm.toString(newId));
        console2.log("maxUsdcIn", MAX_USDC_IN);
    }
}
