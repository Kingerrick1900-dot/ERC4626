// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {KingRssSale} from "../src/KingRssSale.sol";
import {IERC20} from "../src/lib/Core.sol";

/// @dev forge script script/DeployKingRssSale.s.sol:DeployKingRssSale --rpc-url $BASE_RPC --broadcast
contract DeployKingRssSale is Script {
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant KING = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    uint256 constant PRICE = 50_000; // $0.05
    uint256 constant LOAD_RSS = 10_000_000 ether; // $500k capacity @ $0.05

    function run() external {
        uint256 pk = vm.envUint("KING_TOKEN_PRIVATE_KEY");
        vm.startBroadcast(pk);
        KingRssSale sale = new KingRssSale(RSS, USDC, KING, PRICE, KING);
        uint256 loadAmt = IERC20(RSS).balanceOf(KING);
        require(loadAmt > 0, "NO_RSS");
        IERC20(RSS).approve(address(sale), loadAmt);
        sale.load(loadAmt);
        vm.stopBroadcast();
        console2.log("sale", address(sale));
        console2.log("stock", sale.stock());
        console2.log("raiseableUsdc", sale.raiseableUsdc());
    }
}
