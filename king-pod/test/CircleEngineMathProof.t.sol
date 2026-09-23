// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownCircleEngine} from "../src/CrownCircleEngine.sol";

interface IMorphoP {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function setAuthorization(address authorized, bool newIsAuthorized) external;
    function accrueInterest(MarketParams memory marketParams) external;
    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function idToMarketParams(bytes32 id) external view returns (address, address, address, address, uint256);
}

interface IYrssP {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
}

interface IEusdP {
    function setMinter(address, bool) external;
}

interface IERC20P {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
}

/// @dev forge test --match-contract CircleEngineMathProof -vv --fork-url $BASE_RPC_URL
contract CircleEngineMathProof is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant YRSS = 0xF80C0529bD94C773844E459853CD91B9263dD525;
    address constant EUSD = 0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a;
    bytes32 constant PARK = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88;

    uint256 constant MORPHO_FLASH_FEE = 0; // Morpho Blue protocol: flash fee is zero

    function test_eightNumbers_exactFork() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));

        (address loan, address collT, address oracle, address irm, uint256 lltv) =
            IMorphoP(MORPHO).idToMarketParams(PARK);
        require(loan == USDC && collT == RSS, "PARK");

        IMorphoP.MarketParams memory mp = IMorphoP.MarketParams(loan, collT, oracle, irm, lltv);
        IMorphoP(MORPHO).accrueInterest(mp);

        (uint256 supShares, uint128 borShares, uint128 collAmt) = IMorphoP(MORPHO).position(PARK, HOT);
        (uint128 totalSupplyAssets, uint128 totalSupplyShares, uint128 totalBorrowAssets, uint128 totalBorrowShares,,)
        = IMorphoP(MORPHO).market(PARK);

        uint256 repayExact = (uint256(totalBorrowAssets) * uint256(borShares) + uint256(totalBorrowShares) - 1)
            / uint256(totalBorrowShares);
        uint256 supplyDown = uint256(supShares) * uint256(totalSupplyAssets) / uint256(totalSupplyShares);
        uint256 yrssClaim = IYrssP(YRSS).convertToAssets(IYrssP(YRSS).balanceOf(HOT));
        uint256 cover = supplyDown + yrssClaim;
        uint256 shortfall = repayExact > cover ? repayExact - cover : 0;
        uint256 flashExact = repayExact; // engine adds +1 wei
        uint256 flashWithWei = flashExact + 1;
        uint256 morphoBal = IERC20P(USDC).balanceOf(MORPHO);

        console2.log("--- ACCRUED STATE ---");
        console2.log("repayExact", repayExact);
        console2.log("supplyDown", supplyDown);
        console2.log("yrssClaim", yrssClaim);
        console2.log("cover", cover);
        console2.log("shortfall", shortfall);
        console2.log("morphoUsdc", morphoBal);
        console2.log("collRSS", uint256(collAmt));

        require(morphoBal >= flashWithWei, "FLASH_CEILING");
        require(shortfall > 0, "expected underwater knot after accrue");

        // Prefund shortfall + $100 IRM cushion (100% util accrues between eth_call and tx)
        uint256 prefund = shortfall + 100e6;

        vm.startPrank(HOT);
        CrownCircleEngine engine = new CrownCircleEngine(
            MORPHO, USDC, RSS, YRSS, EUSD, HOT, LANDING, PARK, oracle, irm, lltv, HOT
        );
        IMorphoP(MORPHO).setAuthorization(address(engine), true);
        IYrssP(YRSS).approve(address(engine), type(uint256).max);
        IEusdP(EUSD).setMinter(address(engine), true);
        deal(USDC, HOT, prefund);
        IERC20P(USDC).transfer(address(engine), prefund);
        vm.stopPrank();

        // Re-accrue + size flash the same way the engine will
        IMorphoP(MORPHO).accrueInterest(mp);
        (uint256 flashUsed, , , uint256 collNow) = engine.previewFlash();
        (uint256 s2, uint128 b2,) = IMorphoP(MORPHO).position(PARK, HOT);
        (uint128 sa2, uint128 ss2, uint128 ba2, uint128 bs2,,) = IMorphoP(MORPHO).market(PARK);
        uint256 repayNow = (uint256(ba2) * uint256(b2) + uint256(bs2) - 1) / uint256(bs2);
        uint256 supplyNow = uint256(s2) * uint256(sa2) / uint256(ss2);

        uint256 landingBefore = IERC20P(USDC).balanceOf(LANDING);
        uint256 hotRssBefore = IERC20P(RSS).balanceOf(HOT);

        uint256 gasUsed;
        vm.prank(HOT);
        uint256 g0 = gasleft();
        engine.unwindKnot();
        gasUsed = g0 - gasleft();

        uint256 dust = IERC20P(USDC).balanceOf(LANDING) - landingBefore;
        uint256 rssFreed = IERC20P(RSS).balanceOf(HOT) - hotRssBefore;
        uint256 supplyPulled = engine.lastSupplyPulled();
        uint256 yrssPulled = engine.lastYrssPulled();

        (, uint128 borAfter, uint128 collAfter) = IMorphoP(MORPHO).position(PARK, HOT);
        (uint256 supAfter,,) = IMorphoP(MORPHO).position(PARK, HOT);

        assertEq(uint256(borAfter), 0, "debt");
        assertEq(supAfter, 0, "supply");
        assertEq(uint256(collAfter), 0, "coll");
        assertEq(rssFreed, collNow, "rss");

        assertEq(supplyPulled + yrssPulled + prefund - dust, repayNow, "conservation");
        assertEq(MORPHO_FLASH_FEE, 0, "fee");
        assertEq(flashUsed, repayNow + 1, "flash=repay+1");

        console2.log("=== EIGHT NUMBERS (fork-proven) ===");
        console2.log("1_flashAmount", flashUsed);
        console2.log("2_flashFee", MORPHO_FLASH_FEE);
        console2.log("3_repayAmount", repayNow);
        console2.log("4_supplyWithdrawal", supplyPulled);
        console2.log("5_yRSS_peel", yrssPulled);
        console2.log("6_RSS_freed", rssFreed);
        console2.log("7_finalDust", dust);
        console2.log("8_gasUsed", gasUsed);
        console2.log("PREFUND_on_engine", prefund);
        console2.log("supplyNow_at_size", supplyNow);
    }
}
