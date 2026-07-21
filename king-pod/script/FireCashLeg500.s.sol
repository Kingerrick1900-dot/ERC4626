// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20C {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IOracleC {
    function price() external view returns (uint256);
}

interface IMorphoC {
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
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function idToMarketParams(bytes32) external view returns (MarketParams memory);
}

/// @notice SAFE CASH LEG — borrow USDC straight to Landing against RSS (default $700k = desk ceiling).
/// @dev NO yRSS. NO flash. NO circle. Refuses if market idle < MIN_IDLE.
///      Gates: KING_GO=1; FIRE_CASH=1 to broadcast borrow.
///      Override: BORROW_USDC / MIN_IDLE (6dp USDC).
contract FireCashLeg500 is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    bytes32 constant MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    uint256 constant SOFT_LTV_BPS = 7000;
    uint256 constant DEFAULT_BORROW = 700_000e6;
    uint256 constant DEFAULT_MIN_IDLE = 700_000e6;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO-GO: KING_GO=1");

        bool doFire = vm.envOr("FIRE_CASH", uint256(0)) == 1;
        address landing = vm.envOr("LANDING", LANDING);
        uint256 borrowUsdc = vm.envOr("BORROW_USDC", DEFAULT_BORROW);
        uint256 minIdle = vm.envOr("MIN_IDLE", DEFAULT_MIN_IDLE);

        IMorphoC.MarketParams memory mp = IMorphoC(MORPHO).idToMarketParams(MARKET_ID);
        require(mp.loanToken == USDC && mp.collateralToken == RSS, "market");

        (uint128 supply,, uint128 borrowed,,,) = IMorphoC(MORPHO).market(MARKET_ID);
        uint256 idle = uint256(supply) > uint256(borrowed) ? uint256(supply) - uint256(borrowed) : 0;

        uint256 price = IOracleC(ORACLE).price();
        uint256 rssBal = IERC20C(RSS).balanceOf(HOT);

        // RSS needed for borrow at soft LTV + 1% cushion
        uint256 rssNeeded = (borrowUsdc * 10_000 * 1e36) / (SOFT_LTV_BPS * price);
        rssNeeded = (rssNeeded * 101) / 100;
        if (rssNeeded > rssBal) rssNeeded = rssBal;

        uint256 landingBefore = IERC20C(USDC).balanceOf(landing);

        console2.log("=== CASH LEG $500k SAFE TEST ===");
        console2.log("idle", idle);
        console2.log("minIdle", minIdle);
        console2.log("borrowUsdc", borrowUsdc);
        console2.log("rssBal", rssBal);
        console2.log("rssNeeded", rssNeeded);
        console2.log("landing", landing);
        console2.log("doFire", doFire ? uint256(1) : uint256(0));

        require(idle >= minIdle, "NO IDLE: cash-leg blocked until RSS/USDC idle >= MIN_IDLE");
        require(idle >= borrowUsdc, "IDLE < BORROW");
        require(rssNeeded > 0 && rssBal >= rssNeeded, "NEED RSS");
        require(borrowUsdc >= 100_000e6, "SIZE"); // floor $100k — no dust games

        if (!doFire) {
            console2.log("PREFLIGHT OK - set FIRE_CASH=1 to broadcast");
            console2.log("READY", uint256(0));
            return;
        }

        vm.startBroadcast(pk);
        IERC20C(RSS).approve(MORPHO, rssNeeded);
        IMorphoC(MORPHO).supplyCollateral(mp, rssNeeded, HOT, "");
        IMorphoC(MORPHO).borrow(mp, borrowUsdc, 0, HOT, landing);
        vm.stopBroadcast();

        uint256 landingAfter = IERC20C(USDC).balanceOf(landing);
        (, uint128 bor, uint128 coll) = IMorphoC(MORPHO).position(MARKET_ID, HOT);

        console2.log("=== RESULT ===");
        console2.log("landingDelta", landingAfter - landingBefore);
        console2.log("hotDebtShares", uint256(bor));
        console2.log("hotColl", uint256(coll));
        console2.log("READY", landingAfter >= landingBefore + borrowUsdc ? uint256(1) : uint256(0));
        require(landingAfter >= landingBefore + borrowUsdc, "CASH LEG FAIL");
    }
}
