// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20D {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IOracleD {
    function price() external view returns (uint256);
}

interface IMorphoD {
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

/// @notice Real loan: post RSS → borrow USDC → King wallet. No vault. No circle.
/// @dev KING_GO=1 FIRE_DIRECT=1. Refuses thin idle. Only posts RSS needed for the draw.
contract FireDirectBorrow is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    bytes32 constant MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;
    uint256 constant SOFT_LTV_BPS = 7000;
    uint256 constant MIN_IDLE = 500_000e6; // will not fire wallet draw below $500k idle

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "hot");
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NO-GO: KING_GO=1");
        require(vm.envOr("FIRE_DIRECT", uint256(0)) == 1, "NO-FIRE: FIRE_DIRECT=1");

        address kingWallet = vm.envOr("KING_WALLET", LANDING);
        uint256 borrowWanted = vm.envOr("BORROW_USDC", uint256(9_000_000e6));
        uint256 minIdle = vm.envOr("MIN_IDLE_USDC", MIN_IDLE);

        IMorphoD.MarketParams memory mp = IMorphoD(MORPHO).idToMarketParams(MARKET_ID);
        require(mp.loanToken == USDC && mp.collateralToken == RSS, "market");

        (uint128 supply,, uint128 borrowed,,,) = IMorphoD(MORPHO).market(MARKET_ID);
        uint256 idle = uint256(supply) > uint256(borrowed) ? uint256(supply) - uint256(borrowed) : 0;

        uint256 price = IOracleD(ORACLE).price();
        uint256 rssBal = IERC20D(RSS).balanceOf(HOT);
        uint256 collValueUsdc = (rssBal * price) / 1e36;
        uint256 maxBorrowLtv = (collValueUsdc * SOFT_LTV_BPS) / 10_000;

        uint256 borrowUsdc = borrowWanted;
        if (borrowUsdc > maxBorrowLtv) borrowUsdc = maxBorrowLtv;
        if (borrowUsdc > idle) borrowUsdc = idle;

        // RSS required for this borrow at soft LTV (do NOT lock full 18.5M for a small draw)
        uint256 rssNeeded = (borrowUsdc * 10_000 * 1e36) / (SOFT_LTV_BPS * price);
        rssNeeded = (rssNeeded * 101) / 100; // 1% cushion
        if (rssNeeded > rssBal) rssNeeded = rssBal;

        console2.log("=== DIRECT BORROW (no circle) ===");
        console2.log("kingWallet", kingWallet);
        console2.log("marketIdle", idle);
        console2.log("minIdleRequired", minIdle);
        console2.log("borrowWanted", borrowWanted);
        console2.log("borrowUsdc", borrowUsdc);
        console2.log("rssNeeded", rssNeeded);

        require(idle >= minIdle, "IDLE TOO THIN: wait for USDC supply in RSS/USDC market");
        require(borrowUsdc >= minIdle || borrowUsdc == borrowWanted, "draw too small vs policy");
        require(borrowUsdc > 0 && rssNeeded > 0, "zero");

        uint256 walletBefore = IERC20D(USDC).balanceOf(kingWallet);

        vm.startBroadcast(pk);
        IERC20D(RSS).approve(MORPHO, rssNeeded);
        IMorphoD(MORPHO).supplyCollateral(mp, rssNeeded, HOT, "");
        IMorphoD(MORPHO).borrow(mp, borrowUsdc, 0, HOT, kingWallet);
        vm.stopBroadcast();

        uint256 walletAfter = IERC20D(USDC).balanceOf(kingWallet);
        (, uint128 bor, uint128 coll) = IMorphoD(MORPHO).position(MARKET_ID, HOT);

        console2.log("DIRECT_BORROW_DONE");
        console2.log("walletDelta", walletAfter - walletBefore);
        console2.log("hotBorrowShares", uint256(bor));
        console2.log("hotColl", uint256(coll));
    }
}
