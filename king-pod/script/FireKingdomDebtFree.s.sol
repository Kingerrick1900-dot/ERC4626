// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownChunkFreeRss} from "../src/CrownChunkFreeRss.sol";

interface IMorphoAuth {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function isAuthorized(address authorizer, address authorized) external view returns (bool);
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IERC20K {
    function balanceOf(address) external view returns (uint256);
}

interface IYrssK {
    function approve(address, uint256) external returns (bool);
    function totalAssets() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
    function maxWithdraw(address) external view returns (uint256);
}

/// @notice KINGDOM DEBT FREE — pay down Morpho self-seed loan, free RSS asset to hot.
/// @dev RSS is a working asset (not a public meme). Lighter RSS is OK when debt is paid.
///      Gates: KING_GO=1
///        FIRE_FREE=0 → deploy freer + auth + approve only
///        FIRE_FREE=1 → freeRssToKing() (+ optional sweep to Landing)
///      Ops USDC ($500k set): after free, convert freed RSS via OTC/pool (no DEX pool live yet).
contract FireKingdomDebtFree is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO-GO: KING_GO=1");

        bool doFree = vm.envOr("FIRE_FREE", uint256(0)) == 1;
        bool doSweep = vm.envOr("SWEEP_LANDING", uint256(1)) == 1;
        address landing = vm.envOr("LANDING", LANDING);
        address existing = vm.envOr("FREER", address(0));

        (, uint128 borBefore, uint128 collBefore) = IMorphoAuth(MORPHO).position(MID, HOT);
        (,, uint128 tba, uint128 tbs,,) = IMorphoAuth(MORPHO).market(MID);
        uint256 debtBefore;
        if (borBefore > 0 && tbs > 0) {
            debtBefore = (uint256(tba) * uint256(borBefore) + uint256(tbs) - 1) / uint256(tbs);
        }

        console2.log("=== KINGDOM DEBT FREE ===");
        console2.log("debtBefore", debtBefore);
        console2.log("collBefore", uint256(collBefore));
        console2.log("rssHotBefore", IERC20K(RSS).balanceOf(HOT));
        console2.log("yRssTVL", IYrssK(YRSS).totalAssets());
        console2.log("maxWithdraw", IYrssK(YRSS).maxWithdraw(HOT));
        console2.log("doFree", doFree ? uint256(1) : uint256(0));

        if (doFree) {
            require(borBefore > 0 || collBefore > 0, "NO POSITION");
        }

        vm.startBroadcast(pk);

        CrownChunkFreeRss freer;
        if (existing == address(0)) {
            freer = new CrownChunkFreeRss(MORPHO, USDC, RSS, YRSS, HOT, MID, ORACLE, IRM, LLTV, HOT);
            console2.log("freer", address(freer));
        } else {
            freer = CrownChunkFreeRss(existing);
            console2.log("freerExisting", existing);
        }

        if (!IMorphoAuth(MORPHO).isAuthorized(HOT, address(freer))) {
            IMorphoAuth(MORPHO).setAuthorization(address(freer), true);
        }
        IYrssK(YRSS).approve(address(freer), type(uint256).max);

        if (doFree) {
            freer.freeRssToKing();
            if (doSweep) {
                freer.sweepYrssToLanding(landing);
            }
        }

        vm.stopBroadcast();

        (, uint128 borAfter, uint128 collAfter) = IMorphoAuth(MORPHO).position(MID, HOT);
        (,, uint128 tba2, uint128 tbs2,,) = IMorphoAuth(MORPHO).market(MID);
        uint256 debtAfter;
        if (borAfter > 0 && tbs2 > 0) {
            debtAfter = (uint256(tba2) * uint256(borAfter) + uint256(tbs2) - 1) / uint256(tbs2);
        }

        uint256 rssHot = IERC20K(RSS).balanceOf(HOT);
        console2.log("=== RESULT ===");
        console2.log("debtAfter", debtAfter);
        console2.log("collAfter", uint256(collAfter));
        console2.log("rssHotAfter", rssHot);
        console2.log("yRssTVL", IYrssK(YRSS).totalAssets());
        console2.log("landingUsdc", IERC20K(USDC).balanceOf(landing));
        console2.log("READY", doFree ? uint256(1) : uint256(0));

        // Oracle $1 notionals — Morpho book value, NOT a DEX quote
        console2.log("oracleNotionalRssHot", rssHot / 1e18);
        console2.log("NOTE: no RSS/USDC DEX pool on Base yet - ops USDC needs OTC or new pool");
    }
}
