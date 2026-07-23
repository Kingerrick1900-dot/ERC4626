// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownSupplyMagnet} from "../src/CrownSupplyMagnet.sol";

interface IERC20M {
    function approve(address, uint256) external returns (bool);
}

/// @notice ENGINEER 3 — Deploy King book (USDC supply magnet + RSS rebate + King borrow).
/// @dev KING_OK=1 FIRE_BOOK=1
///      REBATE_RSS_PER_USDC default 0.02e18 (0.02 RSS per $1)
///      STOCK_REBATE_RSS default 200_000e18
///      POST_COLL_RSS default 2_000_000e18 (collateral posted; borrow needs USDC suppliers)
contract FireCrownBook is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_BOOK", uint256(0)) == 1, "NO_FIRE");

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        bool deploy = vm.envOr("DEPLOY", uint256(1)) == 1;
        uint256 rebatePer = vm.envOr("REBATE_RSS_PER_USDC", uint256(0.02 ether));
        uint256 stockRebate = vm.envOr("STOCK_REBATE_RSS", uint256(200_000 ether));
        uint256 postColl = vm.envOr("POST_COLL_RSS", uint256(2_000_000 ether));

        vm.startBroadcast(pk);

        CrownSupplyMagnet book;
        if (deploy) {
            book = new CrownSupplyMagnet(USDC, RSS, HOT, HOT);
            console2.log("KingBook", address(book));
        } else {
            book = CrownSupplyMagnet(vm.envAddress("KING_BOOK"));
        }

        book.arm(rebatePer, 700000000000000000);

        if (stockRebate > 0) {
            IERC20M(RSS).approve(address(book), stockRebate);
            book.stockRebate(stockRebate);
            console2.log("rebateBudget", stockRebate);
        }

        if (postColl > 0) {
            IERC20M(RSS).approve(address(book), postColl);
            book.postColl(postColl);
            console2.log("postedColl", postColl);
        }

        console2.log("maxBorrow", book.maxBorrow());
        console2.log("rebateRssPerUsdc", book.rebateRssPerUsdc());

        vm.stopBroadcast();
    }
}
