// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownAtomicDexFlashRouter} from "../src/CrownAtomicDexFlashRouter.sol";

interface IMorphoAuthFire {
    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function isAuthorized(address authorizer, address authorized) external view returns (bool);
}

interface IERC20Fire {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
}

/// @notice Deploy + fire Atomic DEX Flash Router (no Morpho borrow-queue).
/// @dev Env:
///   FIRE=1 broadcast
///   MODE=extract|unwind|deploy (default deploy+quote)
///   RSS_IN / MIN_USDC for extract
///   MIN_LANDING / RSS_SELL_CAP for unwind
contract FireDexFlashRouter is Script {
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant AERO_ROUTER = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43;
    address constant AERO_PAIR = 0x2C4F14744B8b3D087b768D0764d983Acb46d537a;
    address constant AERO_FACTORY = 0x420DD381b31aEf6683db6B902084cB0FFECe40Da;

    function run() external {
        bool fire = vm.envOr("FIRE", uint256(0)) == 1;
        string memory mode = vm.envOr("MODE", string("deploy"));
        address existing = vm.envOr("ROUTER", address(0));

        uint256 rssIn = vm.envOr("RSS_IN", uint256(1000 ether)); // default 1000 RSS probe
        uint256 minUsdc = vm.envOr("MIN_USDC", uint256(1)); // raw 6dp
        uint256 minLanding = vm.envOr("MIN_LANDING", uint256(0));
        uint256 rssSellCap = vm.envOr("RSS_SELL_CAP", uint256(0));

        console2.log("=== ATOMIC DEX FLASH ROUTER ===");
        console2.log("mode", mode);
        console2.log("Aero pair USDC reserve", IERC20Fire(USDC).balanceOf(AERO_PAIR));
        console2.log("Landing USDC", IERC20Fire(USDC).balanceOf(LANDING));
        console2.log("Hot RSS", IERC20Fire(RSS).balanceOf(HOT));

        if (!fire) {
            // Quote only via eth_call deploy in sim
            CrownAtomicDexFlashRouter probe = new CrownAtomicDexFlashRouter(
                MORPHO,
                USDC,
                RSS,
                AERO_ROUTER,
                AERO_PAIR,
                AERO_FACTORY,
                HOT,
                LANDING,
                MARKET_ID,
                ORACLE,
                IRM,
                LLTV,
                HOT
            );
            console2.log("probe router", address(probe));
            console2.log("dexUsdcReserve", probe.dexUsdcReserve());
            console2.log("quoteUsdcOut(rssIn)", probe.quoteUsdcOut(rssIn));
            (uint256 maxRss, uint256 maxOut) = probe.maxRssForDepth(5000);
            console2.log("maxRss at half depth", maxRss);
            console2.log("maxUsdc at half depth", maxOut);
            console2.log("DRY - set FIRE=1 MODE=deploy|extract|unwind");
            return;
        }

        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "NOT_HOT");

        vm.startBroadcast(pk);

        CrownAtomicDexFlashRouter router;
        if (existing == address(0) || keccak256(bytes(mode)) == keccak256(bytes("deploy"))) {
            router = new CrownAtomicDexFlashRouter(
                MORPHO,
                USDC,
                RSS,
                AERO_ROUTER,
                AERO_PAIR,
                AERO_FACTORY,
                HOT,
                LANDING,
                MARKET_ID,
                ORACLE,
                IRM,
                LLTV,
                HOT
            );
            console2.log("DEPLOYED", address(router));
        } else {
            router = CrownAtomicDexFlashRouter(existing);
            console2.log("USING", address(router));
        }

        if (keccak256(bytes(mode)) == keccak256(bytes("extract"))) {
            uint256 allowance = IERC20Fire(RSS).allowance(HOT, address(router));
            if (allowance < rssIn) {
                require(IERC20Fire(RSS).approve(address(router), type(uint256).max), "APPROVE");
            }
            uint256 before = IERC20Fire(USDC).balanceOf(LANDING);
            router.extractUsdc(rssIn, minUsdc);
            console2.log("Landing delta", IERC20Fire(USDC).balanceOf(LANDING) - before);
            console2.log("EXTRACT_OK");
        } else if (keccak256(bytes(mode)) == keccak256(bytes("unwind"))) {
            if (!IMorphoAuthFire(MORPHO).isAuthorized(HOT, address(router))) {
                IMorphoAuthFire(MORPHO).setAuthorization(address(router), true);
            }
            uint256 before = IERC20Fire(USDC).balanceOf(LANDING);
            // Will revert Depth if Aero cannot cover ~$700k debt — honest
            router.flashUnwindExtract(minLanding, rssSellCap);
            console2.log("Landing delta", IERC20Fire(USDC).balanceOf(LANDING) - before);
            console2.log("UNWIND_OK");
        }

        vm.stopBroadcast();
    }
}
