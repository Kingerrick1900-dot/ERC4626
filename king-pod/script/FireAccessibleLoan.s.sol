// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20A {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IOracleA {
    function price() external view returns (uint256);
}

interface IMorphoA {
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

/// @notice ACCESSIBLE LOAN — post RSS, borrow real idle USDC straight to Hot (ops wallet).
/// @dev Debt access law: receiver MUST receive spendable USDC. No flash. No yRSS lock.
///      KING_OK=1 KING_GO=1 FIRE_LOAN=1
///      Default receiver = HOT (token/ops wallet). Set RECEIVER=Landing only if King wants cold.
contract FireAccessibleLoan is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant ORACLE = 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e;
    bytes32 constant RSS77 = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794;

    uint256 constant SOFT_LTV_BPS = 7000;
    uint256 constant HOT_USDC_FLOOR_AFTER = 0; // loan proceeds stay on hot

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(pk) == HOT, "HOT");
        require(vm.envOr("KING_OK", uint256(0)) == 1, "KING_OK");
        require(vm.envOr("KING_GO", uint256(0)) == 1, "KING_GO");
        bool doFire = vm.envOr("FIRE_LOAN", uint256(0)) == 1;

        // Default: Hot ops wallet — King needs USDC here. Override RECEIVER only with King intent.
        address receiver = vm.envOr("RECEIVER", HOT);
        require(receiver == HOT || receiver == LANDING, "RECEIVER hot|landing only");

        uint256 want = vm.envOr("BORROW_USDC", uint256(500_000e6));
        uint256 minBorrow = vm.envOr("MIN_BORROW", uint256(1e6)); // $1 floor — no dust games below $1
        uint256 postRss = vm.envOr("POST_RSS", uint256(1_000_000 ether));

        IMorphoA.MarketParams memory mp = IMorphoA(MORPHO).idToMarketParams(RSS77);
        require(mp.loanToken == USDC && mp.collateralToken == RSS, "market");

        (uint128 supply,, uint128 borrowed,,,) = IMorphoA(MORPHO).market(RSS77);
        uint256 idle = uint256(supply) > uint256(borrowed) ? uint256(supply) - uint256(borrowed) : 0;
        (, uint128 debtShares, uint128 collNow) = IMorphoA(MORPHO).position(RSS77, HOT);

        uint256 rssBal = IERC20A(RSS).balanceOf(HOT);
        uint256 collAfter = uint256(collNow) + postRss;
        if (postRss > rssBal) postRss = rssBal;
        collAfter = uint256(collNow) + postRss;

        // Soft LTV capacity on total coll (existing + new) @ $1 oracle
        uint256 maxByLtv = (collAfter * SOFT_LTV_BPS / 10_000) * 1e6 / 1e18;
        // Approximate existing debt assets from shares if any
        uint256 existingDebt;
        if (debtShares > 0 && borrowed > 0) {
            (,, uint128 bA, uint128 bS,,) = IMorphoA(MORPHO).market(RSS77);
            if (bS > 0) existingDebt = (uint256(debtShares) * uint256(bA)) / uint256(bS);
        }
        uint256 headroom = maxByLtv > existingDebt ? maxByLtv - existingDebt : 0;

        uint256 borrowUsdc = want;
        if (borrowUsdc > idle) borrowUsdc = idle;
        if (borrowUsdc > headroom) borrowUsdc = headroom;

        uint256 recvBefore = IERC20A(USDC).balanceOf(receiver);

        console2.log("=== ACCESSIBLE LOAN (spendable USDC) ===");
        console2.log("receiver", receiver);
        console2.log("idle", idle);
        console2.log("want", want);
        console2.log("borrowUsdc", borrowUsdc);
        console2.log("postRss", postRss);
        console2.log("collNow", uint256(collNow));
        console2.log("headroom", headroom);
        console2.log("recvBefore", recvBefore);
        console2.log("doFire", doFire ? uint256(1) : uint256(0));

        // Access law: refuse if no real idle to put in King's wallet
        require(idle >= minBorrow, "NO IDLE: no accessible Morpho liquidity - wait for lenders/desk fill");
        require(borrowUsdc >= minBorrow, "BORROW TOO SMALL");
        require(postRss > 0 || collNow > 0, "NEED COLLATERAL");

        if (!doFire) {
            console2.log("PREFLIGHT OK - FIRE_LOAN=1 borrows to receiver wallet");
            console2.log("READY", uint256(0));
            return;
        }

        vm.startBroadcast(pk);
        if (postRss > 0) {
            IERC20A(RSS).approve(MORPHO, postRss);
            IMorphoA(MORPHO).supplyCollateral(mp, postRss, HOT, "");
        }
        IMorphoA(MORPHO).borrow(mp, borrowUsdc, 0, HOT, receiver);
        vm.stopBroadcast();

        uint256 recvAfter = IERC20A(USDC).balanceOf(receiver);
        uint256 gain = recvAfter - recvBefore;
        (, uint128 debtAfter, uint128 collAfterOn) = IMorphoA(MORPHO).position(RSS77, HOT);

        console2.log("=== LOAN RESULT ===");
        console2.log("walletGain", gain);
        console2.log("debtShares", uint256(debtAfter));
        console2.log("collPosted", uint256(collAfterOn));
        console2.log("LOAN_OK", gain >= borrowUsdc ? uint256(1) : uint256(0));

        // Debt access law — hard fail if funds not spendable in wallet
        require(gain >= borrowUsdc, "ACCESS FAIL: borrow did not land spendable USDC");
    }
}
