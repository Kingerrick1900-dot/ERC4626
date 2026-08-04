// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {FinishDeleverage} from "../src/FinishDeleverage.sol";

interface IMorphoAuth {
    function setAuthorization(address, bool) external;
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}

interface IERC20A {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IYrssAdmin {
    function setSkimRecipient(address) external;
    function setIsAllocator(address, bool) external;
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

contract FireFinish is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant AERO = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant AERO_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    function run() external {
        require(vm.envOr("FIRE_FINISH", uint256(0)) == 1, "NEED FIRE_FINISH=1");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        vm.startBroadcast(pk);

        // Tiny gap so skim(~$299) + USDC covers exact $300 flash
        uint256 gapRss = 50_000 ether;
        IERC20A(RSS).approve(AERO, gapRss);
        IAeroRouter.Route[] memory routes = new IAeroRouter.Route[](1);
        routes[0] = IAeroRouter.Route({from: RSS, to: USDC, stable: false, factory: AERO_FACTORY});
        IAeroRouter(AERO).swapExactTokensForTokens(gapRss, 1, routes, HOT, block.timestamp + 600);
        console2.log("usdcAfterGap", IERC20A(USDC).balanceOf(HOT));

        FinishDeleverage fin = new FinishDeleverage(
            MORPHO, USDC, RSS, YRSS, HOT, HOT, MID, ORACLE, IRM, LLTV, HOT
        );
        IMorphoAuth(MORPHO).setAuthorization(address(fin), true);
        IYrssAdmin(YRSS).setIsAllocator(address(fin), true);
        IYrssAdmin(YRSS).setSkimRecipient(address(fin));
        IERC20A(USDC).approve(address(fin), type(uint256).max);
        fin.execute();

        vm.stopBroadcast();

        (, uint128 bor, uint128 coll) = IMorphoAuth(MORPHO).position(MID, HOT);
        console2.log("bor", uint256(bor));
        console2.log("coll", uint256(coll));
        console2.log("rss", IERC20A(RSS).balanceOf(HOT));
        console2.log("usdc", IERC20A(USDC).balanceOf(HOT));
        console2.log("DONE", bor == 0 && coll == 0 ? uint256(1) : uint256(0));
    }
}
