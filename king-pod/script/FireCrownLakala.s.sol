// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownLakalaAcquiring} from "../src/china/CrownLakalaAcquiring.sol";
import {CrownLakalaCardBridge} from "../src/china/CrownLakalaCardBridge.sol";
import {RoyalCard} from "../src/royal/RoyalCard.sol";

/// @notice Deploy Crown Lakala-class acquiring + card bridge (+ optional RoyalCard).
/// @dev payToken defaults to Base USDC; override with PAY_TOKEN env for eUSD.
contract FireCrownLakala is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address payToken = vm.envOr("PAY_TOKEN", USDC);
        address owner_ = vm.envOr("OWNER", HOT);
        address attest_ = vm.envOr("ATTEST", address(0));
        uint256 mdrRaw = vm.envOr("MDR_BPS", uint256(100));
        uint16 mdr = uint16(mdrRaw);
        bool deployCard = vm.envOr("DEPLOY_ROYAL_CARD", true);

        address broadcaster = vm.addr(pk);

        vm.startBroadcast(pk);

        CrownLakalaAcquiring acq = new CrownLakalaAcquiring(payToken, owner_, mdr);
        CrownLakalaCardBridge bridge = new CrownLakalaCardBridge(owner_);
        address cardAddr;
        if (deployCard) {
            RoyalCard card = new RoyalCard(payToken, owner_);
            cardAddr = address(card);
        }

        if (owner_ == broadcaster) {
            acq.setModules(attest_, address(bridge), mdr);
            if (cardAddr != address(0)) {
                bridge.wire(cardAddr, address(acq), false);
            }
        }

        vm.stopBroadcast();

        console2.log("CrownLakalaAcquiring", address(acq));
        console2.log("CrownLakalaCardBridge", address(bridge));
        console2.log("RoyalCard", cardAddr);
        console2.log("payToken", payToken);
        console2.log("owner", owner_);
        console2.log("mdrBps", uint256(mdr));
    }
}
