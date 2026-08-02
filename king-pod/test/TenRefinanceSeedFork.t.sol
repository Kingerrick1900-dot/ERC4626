// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";

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
    function repay(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external returns (uint256, uint256);
    function withdraw(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external returns (uint256, uint256);
    function accrueInterest(MarketParams memory) external;
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

contract TenRefinanceSeedForkTest is Test {
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
        // Clear EIP-7702 delegation so prank behaves as EOA
        vm.etch(HOT, hex"");
    }

    function test_refinance_withdraws_700k_seed() public {
        IMorpho.MarketParams memory mp =
            IMorpho.MarketParams(USDC, ELE, ORACLE_10, IRM, LLTV_915);
        IMorpho(MORPHO).accrueInterest(mp);
        (uint256 supShares, uint128 borShares,) = IMorpho(MORPHO).position(TEN, HOT);
        (,, uint128 ba, uint128 bs,,) = IMorpho(MORPHO).market(TEN);
        uint256 debt = (uint256(borShares) * uint256(ba) + uint256(bs) - 1) / uint256(bs);
        console2.log("debt", debt);
        console2.log("borShares", uint256(borShares));

        uint256 hot0 = IERC20(USDC).balanceOf(HOT);
        deal(USDC, HOT, hot0 + debt + 1e6, true);

        vm.startPrank(HOT);
        IERC20(USDC).approve(MORPHO, type(uint256).max);
        // repay by shares to avoid asset rounding panic
        IMorpho(MORPHO).repay(mp, 0, borShares, HOT, "");
        (supShares,,) = IMorpho(MORPHO).position(TEN, HOT);
        console2.log("supSharesAfterRepay", supShares);
        IMorpho(MORPHO).withdraw(mp, 0, supShares, HOT, HOT);
        vm.stopPrank();

        (, uint128 borAfter,) = IMorpho(MORPHO).position(TEN, HOT);
        uint256 usdcAfter = IERC20(USDC).balanceOf(HOT);
        console2.log("usdcAfter", usdcAfter);
        assertEq(uint256(borAfter), 0);
        assertGe(usdcAfter, 500_000e6);
    }
}
