// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownTenSpoilsWar} from "../src/CrownTenSpoilsWar.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function setAuthorization(address, bool) external;
    function repay(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function withdraw(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function withdrawCollateral(MarketParams memory, uint256 assets, address onBehalf, address receiver) external;
    function accrueInterest(MarketParams memory) external;
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

contract TenSpoilsWarForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant ORACLE_10 = 0x04aa048DCb46FC80e9Ebd0717612c9fFF834f385;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    bytes32 constant TEN = 0x96228d1eae39767dda3053b36301b220b74a78adca6ffac5ad6c8b155e51d7cc;
    uint256 constant LLTV_915 = 915000000000000000;

    function setUp() public {
        vm.createSelectFork(vm.envOr("RPC_URL", string("https://mainnet.base.org")));
        vm.etch(HOT, hex"");
    }

    function test_wire_claim_puts_700k_seed_on_hot() public {
        IMorpho.MarketParams memory mp =
            IMorpho.MarketParams(USDC, ELE, ORACLE_10, IRM, LLTV_915);
        IMorpho(MORPHO).accrueInterest(mp);
        (uint256 supShares, uint128 borShares,) = IMorpho(MORPHO).position(TEN, HOT);
        require(borShares > 0 && supShares > 0, "no spoil");
        (,, uint128 ba, uint128 bs,,) = IMorpho(MORPHO).market(TEN);
        uint256 debt = (uint256(borShares) * uint256(ba) + uint256(bs) - 1) / uint256(bs);

        uint256 hot0 = IERC20(USDC).balanceOf(HOT);
        deal(USDC, HOT, hot0 + debt + 1e6, true);

        vm.startPrank(HOT);
        IERC20(USDC).approve(MORPHO, type(uint256).max);
        IMorpho(MORPHO).repay(mp, 0, borShares, HOT, "");
        (supShares,,) = IMorpho(MORPHO).position(TEN, HOT);
        IMorpho(MORPHO).withdraw(mp, 0, supShares, HOT, HOT);
        vm.stopPrank();

        (, uint128 borAfter,) = IMorpho(MORPHO).position(TEN, HOT);
        uint256 usdcAfter = IERC20(USDC).balanceOf(HOT);
        console2.log("SPOILS_usdcAfter", usdcAfter);
        assertEq(uint256(borAfter), 0);
        assertGe(usdcAfter, 500_000e6);
    }

    function test_flash_muster_clears_books_wallet_flat() public {
        IMorpho.MarketParams memory mp =
            IMorpho.MarketParams(USDC, ELE, ORACLE_10, IRM, LLTV_915);
        IMorpho(MORPHO).accrueInterest(mp);
        uint256 hot0 = IERC20(USDC).balanceOf(HOT);
        uint256 ele0 = IERC20(ELE).balanceOf(HOT);

        vm.startPrank(HOT);
        CrownTenSpoilsWar war = new CrownTenSpoilsWar(HOT, ORACLE_10);
        IMorpho(MORPHO).setAuthorization(address(war), true);
        war.musterFlash(true);
        vm.stopPrank();

        (, uint128 borAfter, uint128 collAfter) = IMorpho(MORPHO).position(TEN, HOT);
        (uint256 supAfter,,) = IMorpho(MORPHO).position(TEN, HOT);
        assertEq(uint256(borAfter), 0);
        assertEq(supAfter, 0);
        assertEq(uint256(collAfter), 0);
        // Matched flash muster: USDC flat (dust ok); ELE returned to hot
        assertApproxEqAbs(IERC20(USDC).balanceOf(HOT), hot0, 1e6);
        assertGt(IERC20(ELE).balanceOf(HOT), ele0);
        console2.log("FLASH_MUSTER_ELE", IERC20(ELE).balanceOf(HOT));
    }

    function test_free_ele_keeps_debt() public {
        IMorpho.MarketParams memory mp =
            IMorpho.MarketParams(USDC, ELE, ORACLE_10, IRM, LLTV_915);
        IMorpho(MORPHO).accrueInterest(mp);
        (, uint128 borShares, uint128 coll) = IMorpho(MORPHO).position(TEN, HOT);
        (,, uint128 ba, uint128 bs,,) = IMorpho(MORPHO).market(TEN);
        uint256 debt = (uint256(borShares) * uint256(ba) + uint256(bs) - 1) / uint256(bs);
        uint256 minColl = (debt * 1e18 + LLTV_915 - 1) / LLTV_915;
        minColl = (minColl * 1e36 + 1e35 - 1) / 1e35;
        uint256 keep = minColl * 10;
        uint256 freeAmt = uint256(coll) - keep;

        vm.prank(HOT);
        IMorpho(MORPHO).withdrawCollateral(mp, freeAmt, HOT, HOT);

        (, uint128 borAfter, uint128 collAfter) = IMorpho(MORPHO).position(TEN, HOT);
        assertEq(uint256(borAfter), uint256(borShares));
        assertEq(uint256(collAfter), keep);
        assertGe(IERC20(ELE).balanceOf(HOT), freeAmt);
        console2.log("FREE_ELE", freeAmt);
    }
}
