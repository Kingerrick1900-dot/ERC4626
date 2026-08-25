// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {CrownGoldUsd} from "../src/CrownGoldUsd.sol";
import {CrownSovereignAmo} from "../src/CrownSovereignAmo.sol";
import {CrownSovereignExit} from "../src/CrownSovereignExit.sol";

interface IERC20F {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function mint(address to, uint256 amt) external;
}

interface IMorphoF {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function createMarket(MarketParams memory marketParams) external;
    function setAuthorization(address, bool) external;
    function withdrawCollateral(MarketParams memory, uint256 assets, address onBehalf, address receiver) external;
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}

/// @notice Sovereign idle product: mint idle (not wait) on live $50k eUSD book + open RSS/gUSD book.
/// Path: mint eUSD → supplyAmo (idle) → borrow → wrap face as gUSD.
/// gUSD book: mint eUSD → wrap → supplyAmo gUSD → peel RSS → borrow gUSD to HOT.
/// KING_GO=1 FIRE_IDLE=1 PRIVATE_KEY=… LANDING_PRIVATE_KEY=…
contract FireSovereignIdleProduct is Script {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant GUSD = 0x319A49BB274A826F889C6e7221FA82f24ac8bc5d;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant GATE = 0xab2856626BBd8E6fba9dB93783029eB973E8427F;
    address constant ORACLE50 = 0x264f7AfB8f12028345B87FD5E58F2CF444EebA90;
    address constant AMO_EUSD = 0x8960BdbE760E6C90c53a912063170a2Efb1df4Ed;
    bytes32 constant MID_EUSD50 = 0x6075ba260df7fd5ad5bc9f1de33ac0bc2d8201dbe44b0081e89d9974f179867b;
    uint256 constant LLTV = 770000000000000000;

    function run() external {
        require(vm.envOr("KING_GO", uint256(0)) == 1, "NEED KING_GO=1");
        require(vm.envOr("FIRE_IDLE", uint256(0)) == 1, "NEED FIRE_IDLE=1");

        uint256 hotPk = vm.envUint("PRIVATE_KEY");
        require(vm.addr(hotPk) == HOT, "NOT_HOT");
        uint256 landPk = vm.envOr("LANDING_PRIVATE_KEY", hotPk);

        uint256 mintEusd = vm.envOr("MINT_EUSD", uint256(100_000_000e18));
        uint256 mintGusdPath = vm.envOr("MINT_GUSD_PATH", uint256(100_000_000e18));
        uint256 borrowBps = vm.envOr("BORROW_BPS", uint256(7000)); // 70% of idle
        uint256 wrapBps = vm.envOr("WRAP_BPS", uint256(9000)); // 90% of new HOT eUSD borrow
        uint256 peelRss = vm.envOr("PEEL_RSS", uint256(100_000 ether));
        bool openGusd = vm.envOr("OPEN_GUSD", uint256(1)) == 1;

        CrownSovereignAmo amoE = CrownSovereignAmo(AMO_EUSD);
        IMorphoF.MarketParams memory mpE = IMorphoF.MarketParams({
            loanToken: EUSD, collateralToken: RSS, oracle: ORACLE50, irm: IRM, lltv: LLTV
        });

        // ─── A) SCALE LIVE eUSD/$50k BOOK ───────────────────────────────────
        vm.startBroadcast(hotPk);
        IERC20F(EUSD).mint(LANDING, mintEusd);
        console2.log("mintedEusdToLanding", mintEusd);
        vm.stopBroadcast();

        vm.startBroadcast(landPk);
        IERC20F(EUSD).approve(AMO_EUSD, mintEusd);
        vm.stopBroadcast();

        vm.startBroadcast(hotPk);
        uint256 idleBefore = amoE.idle();
        amoE.supplyAmo(LANDING, mintEusd);
        uint256 idleAfterSupply = amoE.idle();
        console2.log("idleBefore", idleBefore);
        console2.log("idleAfterSupply", idleAfterSupply);

        uint256 borrowAsk = (idleAfterSupply * borrowBps) / 10_000;
        uint256 hotE0 = IERC20F(EUSD).balanceOf(HOT);
        amoE.borrowEusd(borrowAsk, HOT);
        uint256 newEusd = IERC20F(EUSD).balanceOf(HOT) - hotE0;
        console2.log("borrowedEusd", borrowAsk);
        console2.log("newHotEusd", newEusd);

        uint256 wrapAmt = (newEusd * wrapBps) / 10_000;
        if (wrapAmt > 0) {
            IERC20F(EUSD).approve(GUSD, wrapAmt);
            CrownGoldUsd(GUSD).wrap(wrapAmt, HOT);
            console2.log("wrappedToGusd", wrapAmt);
        }
        vm.stopBroadcast();

        // ─── B) OPEN RSS/gUSD/$50k BOOK + MINT IDLE ─────────────────────────
        address amoGAddr;
        bytes32 midG;
        if (openGusd) {
            vm.startBroadcast(hotPk);
            IMorphoF.MarketParams memory mpG = IMorphoF.MarketParams({
                loanToken: GUSD, collateralToken: RSS, oracle: ORACLE50, irm: IRM, lltv: LLTV
            });
            IMorphoF(MORPHO).createMarket(mpG);
            midG = keccak256(abi.encode(mpG));
            (address loan,,,,) = IMorphoF(MORPHO).idToMarketParams(midG);
            require(loan == GUSD, "GUSD_MKT_FAIL");
            console2.logBytes32(midG);

            CrownSovereignAmo amoG = new CrownSovereignAmo(
                MORPHO, GUSD, RSS, GATE, HOT, LANDING, midG, ORACLE50, IRM, LLTV, LANDING
            );
            CrownSovereignExit exitG = new CrownSovereignExit(
                MORPHO, GUSD, RSS, HOT, LANDING, midG, ORACLE50, IRM, LLTV, HOT
            );
            amoGAddr = address(amoG);
            console2.log("amoGusd", amoGAddr);
            console2.log("exitGusd", address(exitG));
            IMorphoF(MORPHO).setAuthorization(amoGAddr, true);
            IMorphoF(MORPHO).setAuthorization(address(exitG), true);

            // mint eUSD → wrap to Landing as gUSD
            IERC20F(EUSD).mint(HOT, mintGusdPath);
            IERC20F(EUSD).approve(GUSD, mintGusdPath);
            CrownGoldUsd(GUSD).wrap(mintGusdPath, LANDING);
            console2.log("gusdToLanding", mintGusdPath);
            vm.stopBroadcast();

            vm.startBroadcast(landPk);
            amoG.setRequireGate(false);
            IMorphoF(MORPHO).setAuthorization(address(exitG), true);
            IERC20F(GUSD).approve(amoGAddr, mintGusdPath);
            vm.stopBroadcast();

            vm.startBroadcast(hotPk);
            amoG.supplyAmo(LANDING, mintGusdPath);
            console2.log("gusdIdle", amoG.idle());

            // Peel RSS from eUSD book (headroom enormous at $50k) → post on gUSD book
            (, uint128 borE, uint128 collE) = IMorphoF(MORPHO).position(MID_EUSD50, HOT);
            console2.log("eusdCollBeforePeel", uint256(collE));
            console2.log("eusdBorShares", uint256(borE));
            require(peelRss > 0 && peelRss <= uint256(collE), "PEEL");
            IMorphoF(MORPHO).withdrawCollateral(mpE, peelRss, HOT, HOT);
            IERC20F(RSS).approve(amoGAddr, peelRss);
            amoG.postCollateral(peelRss);

            uint256 gIdle = amoG.idle();
            uint256 gBorrow = (gIdle * borrowBps) / 10_000;
            uint256 g0 = IERC20F(GUSD).balanceOf(HOT);
            amoG.borrowEusd(gBorrow, HOT);
            console2.log("borrowedGusd", gBorrow);
            console2.log("hotGusdDelta", IERC20F(GUSD).balanceOf(HOT) - g0);
            vm.stopBroadcast();

            vm.startBroadcast(landPk);
            amoG.setRequireGate(true);
            vm.stopBroadcast();
        }

        // ─── C) BOOK SNAPSHOT ───────────────────────────────────────────────
        (uint256 idleE, uint256 supE, uint256 borE2, bool provenE) = amoE.book();
        console2.log("eusdIdle", idleE);
        console2.log("eusdSupply", supE);
        console2.log("eusdBorrow", borE2);
        console2.log("eusdProven", provenE);
        console2.log("hotEusd", IERC20F(EUSD).balanceOf(HOT));
        console2.log("hotGusd", IERC20F(GUSD).balanceOf(HOT));
        if (openGusd && amoGAddr != address(0)) {
            (uint256 idleG, uint256 supG, uint256 borG, bool provenG) = CrownSovereignAmo(amoGAddr).book();
            console2.log("gusdIdleFinal", idleG);
            console2.log("gusdSupply", supG);
            console2.log("gusdBorrow", borG);
            console2.log("gusdProven", provenG);
            console2.logBytes32(midG);
        }
        console2.log("SOVEREIGN_IDLE_PRODUCT_OK", uint256(1));
    }
}
