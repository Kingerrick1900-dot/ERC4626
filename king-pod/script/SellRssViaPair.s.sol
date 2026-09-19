// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "../src/lib/Core.sol";
import {KingPair} from "../src/KingPair.sol";
import {KingSusdc} from "../src/KingSusdc.sol";
import {KingRssSale} from "../src/KingRssSale.sol";

/// @dev Deploy sale desk OR swap RSS→sUSDC on pair if swap() exists on deployed pair.
contract SellRssViaPair is Script {
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant SUSDC = 0x4af86Ac17Eb6F12588b2f3B70969f304933d1021;
    address constant PAIR = 0x56EbFC0Af28E1a9D8e6F9d0F3262ff1ad1a78F8c;
    address constant KING = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    uint256 constant PRICE = 50_000;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        uint256 rssSell = vm.envOr("RSS_SELL", uint256(5_000_000 ether));
        vm.startBroadcast(pk);

        // Try on-chain swap if pair has swapRssForSusdc (new pairs only)
        try KingPair(PAIR).swapRssForSusdc(rssSell, 0, KING) returns (uint256 out) {
            uint256 usdcOut = KingSusdc(SUSDC).redeem(out, KING, KING);
            console2.log("swap susdc", out);
            console2.log("usdc", usdcOut);
        } catch {
            console2.log("pair swap unavailable - deploy KingRssSale rail");
            KingRssSale sale = new KingRssSale(RSS, USDC, KING, PRICE, KING);
            IERC20(RSS).approve(address(sale), rssSell);
            sale.load(rssSell);
            console2.log("sale", address(sale));
            console2.log("stock", sale.stock());
            console2.log("raiseable", sale.raiseableUsdc());
        }

        vm.stopBroadcast();
    }
}
