// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20W {
    function balanceOf(address) external view returns (uint256);
}

interface IMorphoW {
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IYrssW {
    function totalAssets() external view returns (uint256);
    function fee() external view returns (uint96);
}

interface IPAW {
    function flowCaps(address, bytes32) external view returns (uint128, uint128);
}

/// @notice WHALE POSITION scoreboard + staged fires. Default = read-only.
/// @dev LIVE-FIRE-LAW: no broadcast unless King sets KING_OK=1 AND FIRE_WHALE=1.
///      This script refuses deploy/broadcast without both flags.
contract FireWhalePosition is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant DESK = 0xDbf7C4Ad01418ec1b753fa039d5e5B54aF4C065D;
    bytes32 constant RSS_M = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    uint256 constant WHALE_COLL = 10_000_000 ether;
    uint256 constant WHALE_TVL = 5_000_000e6;
    uint256 constant PHASE1 = 500_000e6;

    function run() external view {
        (, , uint128 coll) = IMorphoW(MORPHO).position(RSS_M, HOT);
        (uint128 supply,, uint128 borrowed,,,) = IMorphoW(MORPHO).market(RSS_M);
        uint256 idle = uint256(supply) > uint256(borrowed) ? uint256(supply) - uint256(borrowed) : 0;
        uint256 freeRss = IERC20W(RSS).balanceOf(HOT);
        uint256 land = IERC20W(USDC).balanceOf(LAND);
        uint256 tvl = IYrssW(YRSS).totalAssets();
        (uint128 maxIn, uint128 maxOut) = IPAW(PA).flowCaps(YRSS, RSS_M);

        console2.log("=== WHALE POSITION SCOREBOARD (read-only) ===");
        console2.log("freeRss", freeRss);
        console2.log("postedColl", uint256(coll));
        console2.log("whaleCollTarget", WHALE_COLL);
        console2.log("yrssTvl", tvl);
        console2.log("whaleTvlTarget", WHALE_TVL);
        console2.log("paMaxIn", uint256(maxIn));
        console2.log("paMaxOut", uint256(maxOut));
        console2.log("rssIdle", idle);
        console2.log("landing", land);
        console2.log("phase1", PHASE1);
        console2.log("deskRss", IERC20W(RSS).balanceOf(DESK));
        console2.log("feeWad", uint256(IYrssW(YRSS).fee()));

        bool duck = uint256(coll) < WHALE_COLL && tvl < WHALE_TVL && land < PHASE1;
        console2.log("SITTING_DUCK", duck ? uint256(1) : uint256(0));
        console2.log("NOTE: deploy CrownFirstWhale / scale coll / raise caps ONLY on King OK");
    }
}
