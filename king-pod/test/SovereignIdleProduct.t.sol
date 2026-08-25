// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownGoldUsd} from "../src/CrownGoldUsd.sol";
import {CrownSovereignAmo} from "../src/CrownSovereignAmo.sol";
import {CrownSovereignExit} from "../src/CrownSovereignExit.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function mint(address to, uint256 amt) external;
    function isMinter(address) external view returns (bool);
}

interface IMorphoT {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function createMarket(MarketParams memory) external;
    function setAuthorization(address, bool) external;
    function withdrawCollateral(MarketParams memory, uint256 assets, address onBehalf, address receiver) external;
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}

/// @notice Fork proof: idle is minted — scale eUSD/$50k + open RSS/gUSD/$50k.
contract SovereignIdleProductFork is Test {
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

    uint256 constant MINT = 10_000_000e18; // 10M fork chunk (full 100M on live fire)

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
    }

    function test_mint_idle_scale_eusd_and_open_gusd_book() public {
        require(IERC20T(EUSD).isMinter(HOT), "HOT not minter");

        CrownSovereignAmo amoE = CrownSovereignAmo(AMO_EUSD);
        uint256 idle0 = amoE.idle();
        uint256 g0 = IERC20T(GUSD).balanceOf(HOT);

        // A) Scale eUSD book
        vm.prank(HOT);
        IERC20T(EUSD).mint(LANDING, MINT);
        vm.prank(LANDING);
        IERC20T(EUSD).approve(AMO_EUSD, MINT);
        vm.prank(HOT);
        amoE.supplyAmo(LANDING, MINT);
        assertGe(amoE.idle(), idle0 + MINT - 1, "eusd idle miss");

        uint256 borrowAsk = (amoE.idle() * 7000) / 10_000;
        uint256 e0 = IERC20T(EUSD).balanceOf(HOT);
        vm.prank(HOT);
        amoE.borrowEusd(borrowAsk, HOT);
        uint256 newE = IERC20T(EUSD).balanceOf(HOT) - e0;
        assertEq(newE, borrowAsk, "borrow miss");

        uint256 wrapAmt = (newE * 9000) / 10_000;
        vm.startPrank(HOT);
        IERC20T(EUSD).approve(GUSD, wrapAmt);
        CrownGoldUsd(GUSD).wrap(wrapAmt, HOT);
        vm.stopPrank();
        assertEq(IERC20T(GUSD).balanceOf(HOT), g0 + wrapAmt, "wrap miss");

        // B) Open RSS/gUSD book
        IMorphoT.MarketParams memory mpG = IMorphoT.MarketParams({
            loanToken: GUSD, collateralToken: RSS, oracle: ORACLE50, irm: IRM, lltv: LLTV
        });
        vm.prank(HOT);
        IMorphoT(MORPHO).createMarket(mpG);
        bytes32 midG = keccak256(abi.encode(mpG));
        (address loan,,,,) = IMorphoT(MORPHO).idToMarketParams(midG);
        assertEq(loan, GUSD, "mkt");

        vm.startPrank(HOT);
        CrownSovereignAmo amoG = new CrownSovereignAmo(
            MORPHO, GUSD, RSS, GATE, HOT, LANDING, midG, ORACLE50, IRM, LLTV, LANDING
        );
        new CrownSovereignExit(MORPHO, GUSD, RSS, HOT, LANDING, midG, ORACLE50, IRM, LLTV, HOT);
        IMorphoT(MORPHO).setAuthorization(address(amoG), true);

        IERC20T(EUSD).mint(HOT, MINT);
        IERC20T(EUSD).approve(GUSD, MINT);
        CrownGoldUsd(GUSD).wrap(MINT, LANDING);
        vm.stopPrank();

        vm.prank(LANDING);
        amoG.setRequireGate(false);
        vm.prank(LANDING);
        IERC20T(GUSD).approve(address(amoG), MINT);

        vm.prank(HOT);
        amoG.supplyAmo(LANDING, MINT);
        assertGe(amoG.idle(), MINT, "gusd idle miss");

        // Peel RSS → borrow gUSD
        IMorphoT.MarketParams memory mpE = IMorphoT.MarketParams({
            loanToken: EUSD, collateralToken: RSS, oracle: ORACLE50, irm: IRM, lltv: LLTV
        });
        uint256 peel = 50_000 ether;
        vm.startPrank(HOT);
        IMorphoT(MORPHO).withdrawCollateral(mpE, peel, HOT, HOT);
        IERC20T(RSS).approve(address(amoG), peel);
        amoG.postCollateral(peel);
        uint256 gBorrow = (amoG.idle() * 7000) / 10_000;
        uint256 gHot0 = IERC20T(GUSD).balanceOf(HOT);
        amoG.borrowEusd(gBorrow, HOT);
        vm.stopPrank();

        assertEq(IERC20T(GUSD).balanceOf(HOT) - gHot0, gBorrow, "gusd borrow miss");
        console2.log("eusdIdle", amoE.idle());
        console2.log("gusdIdle", amoG.idle());
        console2.log("hotGusd", IERC20T(GUSD).balanceOf(HOT));
        console2.logBytes32(midG);
    }
}
