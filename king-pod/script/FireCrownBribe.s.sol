// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownBribeBudget} from "../src/CrownBribeBudget.sol";

interface IERC20B {
    function approve(address, uint256) external returns (bool);
}

/// @notice ENGINEER 2 — Deploy bribe budget, set RSS/USDC pool, stock RSS.
/// @dev KING_OK=1 FIRE_BRIBE=1
///      STOCK_RSS (default 500_000e18) TRY_GAUGE=0 DIRECT_REBATE_TO + DIRECT_RSS optional
contract FireCrownBribe is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant POOL = 0x2C4F14744B8b3D087b768D0764d983Acb46d537a;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_BRIBE", uint256(0)) == 1, "NO_FIRE");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 stockRss = vm.envOr("STOCK_RSS", uint256(500_000 ether));
        bool deploy = vm.envOr("DEPLOY", uint256(1)) == 1;

        vm.startBroadcast(pk);

        CrownBribeBudget b;
        if (deploy) {
            b = new CrownBribeBudget(RSS, HOT, HOT);
            console2.log("BribeBudget", address(b));
        } else {
            b = CrownBribeBudget(vm.envAddress("BRIBE_BUDGET"));
        }

        b.setPool(POOL);
        console2.log("gauge", b.gauge());
        console2.log("bribe", b.bribe());

        if (vm.envOr("TRY_GAUGE", uint256(0)) == 1) {
            b.tryCreateGauge();
            console2.log("gaugeAfter", b.gauge());
        }

        if (stockRss > 0) {
            IERC20B(RSS).approve(address(b), stockRss);
            b.stock(stockRss);
            console2.log("stocked", stockRss);
        }

        address rebateTo = vm.envOr("DIRECT_REBATE_TO", address(0));
        uint256 rebateAmt = vm.envOr("DIRECT_RSS", uint256(0));
        if (rebateTo != address(0) && rebateAmt > 0) {
            b.directRebate(rebateTo, rebateAmt);
            console2.log("directRebate", rebateAmt);
        }

        if (vm.envOr("PUSH_BRIBE", uint256(0)) == 1) {
            uint256 amt = vm.envOr("BRIBE_RSS", stockRss);
            b.bribeGauge(amt);
            console2.log("bribed", amt);
        }

        vm.stopBroadcast();
    }
}
