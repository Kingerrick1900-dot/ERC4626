// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownFlashFreeRss} from "../src/CrownFlashFreeRss.sol";

interface IMorphoAuth {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
}

interface IERC20A {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

interface IMetaMorphoA {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

/// @notice Deploy CrownFlashFreeRss, authorize, prefund gap USDC, free Morpho RSS to hot.
/// @dev Hot must hold ~$500 USDC for share/fee rounding gap on the $9M self-seed book.
contract DeployAndFreeRss is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    uint256 constant GAP_PREFUND = 500e6; // $500

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");

        (, uint128 bor, uint128 coll) = IMorphoAuth(MORPHO).position(MID, HOT);
        console2.log("borShares", uint256(bor));
        console2.log("coll", uint256(coll));
        console2.log("hotUsdc", IERC20A(USDC).balanceOf(HOT));
        require(IERC20A(USDC).balanceOf(HOT) >= GAP_PREFUND, "NEED_$500_USDC_ON_HOT");

        vm.startBroadcast(pk);

        CrownFlashFreeRss freer = new CrownFlashFreeRss(
            MORPHO, USDC, RSS, YRSS, HOT, MID, ORACLE, IRM, LLTV, HOT
        );
        console2.log("freer", address(freer));

        IMorphoAuth(MORPHO).setAuthorization(address(freer), true);
        IMetaMorphoA(YRSS).approve(address(freer), type(uint256).max);
        // Cover Morpho toAssetsUp / yRSS fee rounding gap after util collapses
        IERC20A(USDC).transfer(address(freer), GAP_PREFUND);

        freer.freeRss();

        vm.stopBroadcast();

        (, uint128 bor2, uint128 coll2) = IMorphoAuth(MORPHO).position(MID, HOT);
        console2.log("borAfter", uint256(bor2));
        console2.log("collAfter", uint256(coll2));
        console2.log("rssBal", IERC20A(RSS).balanceOf(HOT));
        console2.log("usdcBal", IERC20A(USDC).balanceOf(HOT));
    }
}
