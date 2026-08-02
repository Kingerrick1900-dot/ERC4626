// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownFreeFatBooks} from "../src/CrownFreeFatBooks.sol";

interface IERC20U {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function withdraw(uint256) external;
}

interface IMorphoAuth {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface IAeroRouter {
    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

/// @notice COMPLETE free — RSS/WETH + RSS/cbBTC fat books → hot. Zero debt left.
/// @dev KING_OK=1 FIRE_FREE_FAT=1 forge script … --broadcast
contract FireFreeFatBooks is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant CBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant ORA_W = 0x3BB87B8ef3Df289C82540F89DE3e4f7762Ed4A98;
    address constant ORA_C = 0x7c60830200D14F7cDd020bd1c0Aa10d6F254bd0b;
    // Aerodrome Router — Uni SwapRouter02 has no code on Base
    address constant AERO_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant AERO_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant IDW = 0x6d0c2531ad3078b19f569d3d9b48fb9348682a1b769f726c4196e6091a3c35e9;
    bytes32 constant IDC = 0x88fb488074c9f9f3acaa5f84a2f4181bc371defa66ff4a9e42e1e5f0d563be0e;

    function run() external {
        require(vm.envOr("KING_OK", uint256(0)) == 1, "NO_KING_OK");
        require(vm.envOr("FIRE_FREE_FAT", uint256(0)) == 1, "NO_FIRE");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        uint256 rssBefore = IERC20U(RSS).balanceOf(HOT);
        console2.log("RSS before", rssBefore);

        vm.startBroadcast(pk);

        // Gas from WETH if needed; keep ≥0.00005 WETH for 1-wei Morpho gap
        uint256 wethBal = IERC20U(WETH).balanceOf(HOT);
        if (HOT.balance < 0.0002 ether && wethBal > 0.00025 ether) {
            uint256 unwrapAmt = wethBal - 0.00015 ether;
            IERC20U(WETH).withdraw(unwrapAmt);
            console2.log("unwrapped WETH", unwrapAmt);
        }

        // Micro-buy cbBTC (≥1 sat) so full close can cover Morpho share rounding
        if (IERC20U(CBTC).balanceOf(HOT) == 0) {
            uint256 spend = 0.00005 ether; // tiny WETH → ≥1 sat on Aero WETH/cbBTC
            require(IERC20U(WETH).balanceOf(HOT) >= spend + 0.00005 ether, "WETH_LOW");
            IERC20U(WETH).approve(AERO_ROUTER, spend);
            IAeroRouter.Route[] memory routes = new IAeroRouter.Route[](1);
            routes[0] = IAeroRouter.Route({from: WETH, to: CBTC, stable: false, factory: AERO_FACTORY});
            uint256[] memory amounts = IAeroRouter(AERO_ROUTER).swapExactTokensForTokens(
                spend, 1, routes, HOT, block.timestamp + 600
            );
            console2.log("cbBTC bought", amounts[amounts.length - 1]);
            require(amounts[amounts.length - 1] >= 1, "NO_CBTC");
        }

        console2.log("hot ETH", HOT.balance);
        console2.log("hot WETH", IERC20U(WETH).balanceOf(HOT));
        console2.log("hot cbBTC", IERC20U(CBTC).balanceOf(HOT));

        CrownFreeFatBooks freer = new CrownFreeFatBooks(MORPHO, RSS, HOT, HOT);
        console2.log("Freer", address(freer));

        IMorphoAuth(MORPHO).setAuthorization(address(freer), true);
        IERC20U(WETH).approve(address(freer), type(uint256).max);
        IERC20U(CBTC).approve(address(freer), type(uint256).max);

        freer.freeBook(WETH, ORA_W, IRM, LLTV, IDW);
        freer.freeBook(CBTC, ORA_C, IRM, LLTV, IDC);

        IMorphoAuth(MORPHO).setAuthorization(address(freer), false);

        vm.stopBroadcast();

        (uint256 sW, uint128 bW, uint128 cW) = IMorphoAuth(MORPHO).position(IDW, HOT);
        (uint256 sC, uint128 bC, uint128 cC) = IMorphoAuth(MORPHO).position(IDC, HOT);
        uint256 rssAfter = IERC20U(RSS).balanceOf(HOT);
        console2.log("RSS after", rssAfter);
        console2.log("RSS freed", rssAfter - rssBefore);
        console2.log("WETH pos", sW, uint256(bW), uint256(cW));
        console2.log("cbBTC pos", sC, uint256(bC), uint256(cC));
        console2.log("hot WETH", IERC20U(WETH).balanceOf(HOT));
        console2.log("hot cbBTC", IERC20U(CBTC).balanceOf(HOT));
        require(bW == 0 && cW == 0 && sW == 0, "WETH_NOT_CLEAR");
        require(bC == 0 && cC == 0 && sC == 0, "CBTC_NOT_CLEAR");
        console2.log("FREE_FAT_COMPLETE", uint256(1));
    }
}
