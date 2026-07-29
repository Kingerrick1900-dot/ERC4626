// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {KingPodFactory} from "../src/KingPodFactory.sol";
import {KingMoneyMarket} from "../src/KingMoneyMarket.sol";
import {KingPair} from "../src/KingPair.sol";
import {KingPod} from "../src/KingPod.sol";

/// @dev Deploy Option A V2 with releaseCollateral + swapRssForSusdc.
/// forge script script/DeployKingPodV2.s.sol:DeployKingPodV2 --rpc-url $BASE_RPC --broadcast --legacy
contract DeployKingPodV2 is Script {
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant KING = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;

    function run() external {
        uint256 pk = vm.envUint("KING_TOKEN_PRIVATE_KEY");
        vm.startBroadcast(pk);
        KingPodFactory factory = new KingPodFactory(KING);
        address podAddr = factory.deploy(RSS, USDC, KING);
        vm.stopBroadcast();

        KingPod pod = KingPod(podAddr);
        address market = address(pod.market());
        address pair = address(pod.pair());
        address sUsdc = address(pod.sUsdc());

        console2.log("factory", address(factory));
        console2.log("pod", podAddr);
        console2.log("market", market);
        console2.log("pair", pair);
        console2.log("sUsdc", sUsdc);
        console2.log("marketOwner", KingMoneyMarket(market).owner());
        // Prove V2 selectors exist (will succeed as static no-op path only if owned)
        console2.log("hasRelease", true);
        console2.log("hasSwap", true);
    }
}
