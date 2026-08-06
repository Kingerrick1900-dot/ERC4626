// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownRssWethDesk} from "../src/CrownRssWethDesk.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IMorphoT {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function supplyCollateral(MarketParams calldata, uint256, address, bytes calldata) external;
    function borrow(MarketParams calldata, uint256, uint256, address, address) external returns (uint256, uint256);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IPsmT {
    function seed(address, uint256) external;
    function usdcReserve() external view returns (uint256);
    function redeemAsset(address, uint256, address) external;
    function owner() external view returns (address);
}

interface IEusdT {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @notice GO-B fork: WETH loan desk → Morpho WETH/USDC borrow → PSM seed → eUSD redeem USDC.
contract GobBluechipUsdcPsmFork is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant PSM = 0xF7337A26d9456e42a36531A12036A4556EF1F987;
    address constant RSS_ORACLE = 0xB5840644142B341a6145335e2ebc82EEBC7aE1B9;
    address constant WETH_ORACLE = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 0.86e18;

    bytes32 constant WETH_USDC = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;

    function test_gob_weth_loan_borrow_usdc_seed_psm() public {
        uint256 wethLoan = 50e18; // ~$95k coll → borrow ~$70k at ~75% of LLTV
        uint256 usdcBorrow = 70_000e6;
        uint256 rssLock = 200e18; // at $1200 plenty for WETH desk LTV

        address lender = address(0xBEEF);
        deal(WETH, lender, wethLoan);
        // ensure hot has RSS
        uint256 freeRss = IERC20T(RSS).balanceOf(HOT);
        require(freeRss >= rssLock, "RSS");

        // 1) RSS-secured WETH loan (not a sale)
        vm.startPrank(HOT);
        CrownRssWethDesk desk =
            new CrownRssWethDesk(RSS, WETH, RSS_ORACLE, WETH_ORACLE, HOT, 0.75e18);
        vm.stopPrank();

        vm.startPrank(lender);
        IERC20T(WETH).approve(address(desk), wethLoan);
        desk.fund(wethLoan);
        vm.stopPrank();

        vm.startPrank(HOT);
        IERC20T(RSS).approve(address(desk), rssLock);
        desk.draw(rssLock, wethLoan, HOT);
        assertEq(IERC20T(WETH).balanceOf(HOT), wethLoan);

        // 2) Post WETH on deep Morpho WETH/USDC (idle ~$8M) → borrow USDC
        IMorphoT.MarketParams memory mp =
            IMorphoT.MarketParams(USDC, WETH, WETH_ORACLE, IRM, LLTV);
        IERC20T(WETH).approve(MORPHO, wethLoan);
        IMorphoT(MORPHO).supplyCollateral(mp, wethLoan, HOT, "");
        IMorphoT(MORPHO).borrow(mp, usdcBorrow, 0, HOT, HOT);
        assertGe(IERC20T(USDC).balanceOf(HOT), usdcBorrow);

        // 3) Seed Multi-PSM (owner = hot)
        IERC20T(USDC).approve(PSM, usdcBorrow);
        IPsmT(PSM).seed(USDC, usdcBorrow);
        assertGe(IPsmT(PSM).usdcReserve(), usdcBorrow);

        // 4) Redeem eUSD → USDC into Landing (spend rail)
        uint256 redeemEusd = 50_000e18;
        vm.stopPrank();
        // simulate ops eUSD already on Landing moving through hot redeem
        deal(EUSD, HOT, redeemEusd);

        vm.startPrank(HOT);
        IEusdT(EUSD).approve(PSM, redeemEusd);
        uint256 landUsdcBefore = IERC20T(USDC).balanceOf(LANDING);
        IPsmT(PSM).redeemAsset(USDC, redeemEusd, LANDING);
        uint256 landUsdcAfter = IERC20T(USDC).balanceOf(LANDING);
        vm.stopPrank();

        assertGe(landUsdcAfter, landUsdcBefore + 49_000e6); // allow fee dust
        console2.log("PASS GO-B: WETH loan -> USDC borrow -> PSM seed -> eUSD redeem");
        console2.log("LANDING_USDC", landUsdcAfter);
        console2.log("PSM_USDC_RESERVE", IPsmT(PSM).usdcReserve());
    }
}
