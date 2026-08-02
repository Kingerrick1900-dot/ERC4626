// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownMultiStableRail} from "../src/CrownMultiStableRail.sol";

interface IERC20M {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @notice Deploy multi-stable / ETH OTC rail. Focus: DAI · USDT · WETH · ETH · USDC→ETH CCTP.
/// @dev KING_OK=1 FIRE_MULTI_STABLE=1 STOCK_RSS=700000e18
contract FireMultiStableRail is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    // Base canonical / bridged
    address constant DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
    address constant USDT = 0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant TOKEN_MESSENGER = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_MULTI_STABLE", uint256(0)) == 1, "NO_FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 stockRss = vm.envOr("STOCK_RSS", uint256(700_000 ether));

        vm.startBroadcast(pk);
        CrownMultiStableRail rail =
            new CrownMultiStableRail(DAI, USDT, USDC, WETH, RSS, TOKEN_MESSENGER, LANDING, HOT);

        uint256 bal = IERC20M(RSS).balanceOf(HOT);
        if (stockRss > bal) stockRss = bal;
        if (stockRss > 0) {
            IERC20M(RSS).approve(address(rail), stockRss);
            rail.stockRss(stockRss);
        }
        vm.stopBroadcast();

        console2.log("CrownMultiStableRail", address(rail));
        console2.log("DAI", DAI);
        console2.log("USDT", USDT);
        console2.log("USDC", USDC);
        console2.log("WETH", WETH);
        console2.log("landing", LANDING);
        console2.log("stockedRss", stockRss);
        console2.log("DESK_DAI", "fillStable(DAI, amt6, amt*1e12, 1)");
        console2.log("DESK_USDT", "fillStable(USDT, amt6, amt*1e12, 1)");
        console2.log("DESK_USDC_ETH", "fillStable(USDC, amt6, amt*1e12, 2) CCTP");
        console2.log("DESK_WETH", "fillWeth(wethWei, rssOut)");
        console2.log("DESK_ETH", "fillEth{value: wei}(rssOut)");
        console2.log("ETH_MAINNET_WIRE", "desk can also send DAI/USDT/ETH/USDC on Ethereum to Landing EOA");
        console2.log("MULTI_STABLE_ARMED", uint256(1));
    }
}
