// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownRssDutchBond} from "../src/CrownRssDutchBond.sol";
import {CrownFirstWhale} from "../src/CrownFirstWhale.sol";
import {CrownSpoilsRouter} from "../src/CrownSpoilsRouter.sol";

interface IERC20W {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @notice WAR CHEST — Dutch bond + First Whale rebate + Spoils router. RSS pays, USDC returns.
/// @dev KING_OK=1 FIRE_WAR=1. Stocks RSS from hot (no King debit).
contract FireWarChest is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(vm.envOr("KING_OK", uint256(0)) == 1, "KING_OK");
        require(vm.envOr("FIRE_WAR", uint256(0)) == 1, "FIRE_WAR");

        uint256 dutchStock = vm.envOr("DUTCH_STOCK", uint256(500_000 ether));
        uint256 whaleRebate = vm.envOr("WHALE_REBATE", uint256(50_000 ether));
        uint256 floor = vm.envOr("DUTCH_FLOOR", uint256(0.94e6));
        uint256 ceiling = vm.envOr("DUTCH_CEIL", uint256(0.99e6));
        uint256 duration = vm.envOr("DUTCH_DURATION", uint256(7 days));

        console2.log("rssHot", IERC20W(RSS).balanceOf(HOT));
        console2.log("dutchStock", dutchStock);
        console2.log("whaleRebate", whaleRebate);

        vm.startBroadcast(pk);

        CrownSpoilsRouter router = new CrownSpoilsRouter(LANDING, HOT);
        CrownRssDutchBond dutch = new CrownRssDutchBond(RSS, USDC, HOT, HOT);
        CrownFirstWhale whale = new CrownFirstWhale(USDC, RSS, YRSS, HOT, HOT);

        IERC20W(RSS).approve(address(dutch), dutchStock);
        dutch.stock(dutchStock);
        dutch.armDutch(LANDING, floor, ceiling, duration, 500_000e6, true);

        IERC20W(RSS).approve(address(whale), whaleRebate);
        whale.stockRebate(whaleRebate);
        whale.arm(500_000e6, true);

        vm.stopBroadcast();

        console2.log("spoilsRouter", address(router));
        console2.log("dutchBond", address(dutch));
        console2.log("firstWhale", address(whale));
        console2.log("dutchPriceNow", dutch.currentPrice());
        console2.log("dutchRss", dutch.rssForBond());
        console2.log("whaleRebateBudget", whale.rebateBudget());
        console2.log("WAR_CHEST_OK", uint256(1));
    }
}
