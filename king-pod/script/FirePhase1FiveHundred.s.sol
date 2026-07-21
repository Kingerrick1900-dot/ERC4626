// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20P {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IOracleP {
    function price() external view returns (uint256);
}

interface IMorphoP {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supplyCollateral(MarketParams memory, uint256 assets, address onBehalf, bytes memory data) external;
    function borrow(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function idToMarketParams(bytes32) external view returns (MarketParams memory);
}

interface IDeskP {
    function live() external view returns (bool);
    function rssForSale() external view returns (uint256);
    function raisedUsdc() external view returns (uint256);
    function quoteUsdc(uint256) external view returns (uint256);
}

/// @notice PHASE 1 - Bring King $500k to Landing.
/// @dev Prefers cash-leg when RSS idle >= $500k. Desk path is off-chain counterparty
///      (see OPS-COUNTERPARTY-PACKET). Gates: KING_GO=1; FIRE_P1=1 to broadcast borrow.
contract FirePhase1FiveHundred is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    address constant DESK = 0xDbf7C4Ad01418ec1b753fa039d5e5B54aF4C065D;
    bytes32 constant MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    uint256 constant SOFT_LTV_BPS = 7000;
    uint256 constant PHASE1 = 500_000e6;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO-GO: KING_GO=1");

        bool doFire = vm.envOr("FIRE_P1", uint256(0)) == 1;
        uint256 borrowUsdc = vm.envOr("BORROW_USDC", PHASE1);
        require(borrowUsdc == PHASE1, "PHASE1_SIZE_500k");

        // Desk scoreboard (Gun A - human fill)
        console2.log("=== PHASE 1 $500k TO LANDING ===");
        console2.log("deskLive", IDeskP(DESK).live() ? uint256(1) : uint256(0));
        console2.log("deskRssForSale", IDeskP(DESK).rssForSale());
        console2.log("deskRaised", IDeskP(DESK).raisedUsdc());
        console2.log("deskQuote500k", IDeskP(DESK).quoteUsdc(500_000 ether));
        console2.log("landingUsdc", IERC20P(USDC).balanceOf(LANDING));

        if (IERC20P(USDC).balanceOf(LANDING) >= PHASE1) {
            console2.log("PHASE1 ALREADY WON");
            console2.log("READY", uint256(1));
            return;
        }

        IMorphoP.MarketParams memory mp = IMorphoP(MORPHO).idToMarketParams(MARKET_ID);
        (uint128 supply,, uint128 borrowed,,,) = IMorphoP(MORPHO).market(MARKET_ID);
        uint256 idle = uint256(supply) > uint256(borrowed) ? uint256(supply) - uint256(borrowed) : 0;
        console2.log("rssIdle", idle);
        console2.log("needIdle", PHASE1);

        if (idle < PHASE1) {
            console2.log("GUN B BLOCKED: need RSS idle >= $500k OR desk Gun A fill");
            console2.log("ACTION: send CAPITAL-POOLS-PACKET + OPS-COUNTERPARTY-PACKET");
            console2.log("READY", uint256(0));
            return;
        }

        uint256 price = IOracleP(ORACLE).price();
        uint256 rssBal = IERC20P(RSS).balanceOf(HOT);
        uint256 rssNeeded = (borrowUsdc * 10_000 * 1e36) / (SOFT_LTV_BPS * price);
        rssNeeded = (rssNeeded * 101) / 100;
        if (rssNeeded > rssBal) rssNeeded = rssBal;
        console2.log("rssNeeded", rssNeeded);
        require(rssNeeded > 0 && rssBal >= rssNeeded, "NEED RSS");

        if (!doFire) {
            console2.log("PREFLIGHT OK - set FIRE_P1=1 to borrow $500k to Landing");
            console2.log("READY", uint256(0));
            return;
        }

        uint256 before = IERC20P(USDC).balanceOf(LANDING);
        vm.startBroadcast(pk);
        IERC20P(RSS).approve(MORPHO, rssNeeded);
        IMorphoP(MORPHO).supplyCollateral(mp, rssNeeded, HOT, "");
        IMorphoP(MORPHO).borrow(mp, borrowUsdc, 0, HOT, LANDING);
        vm.stopBroadcast();

        uint256 after_ = IERC20P(USDC).balanceOf(LANDING);
        console2.log("landingDelta", after_ - before);
        require(after_ >= before + PHASE1, "PHASE1 FAIL");
        console2.log("PHASE1 WON");
        console2.log("READY", uint256(1));
    }
}
