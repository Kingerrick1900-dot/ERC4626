// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownForceShareUsdc} from "../src/CrownForceShareUsdc.sol";

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

    function accrueInterest(MarketParams memory) external;
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function setAuthorization(address, bool) external;
    function withdrawCollateral(MarketParams memory, uint256 assets, address onBehalf, address receiver) external;
    function withdraw(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, address receiver)
        external
        returns (uint256, uint256);
    function repay(MarketParams memory, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
}

contract UnwindAllForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant ORACLE_77 = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant ORACLE_10 = 0x04aa048DCb46FC80e9Ebd0717612c9fFF834f385;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant FORCE_HELPER = 0x2D7C6966932e586fa65a2BC43a53F770Fe73C0a6;
    bytes32 constant TEN = 0x96228d1eae39767dda3053b36301b220b74a78adca6ffac5ad6c8b155e51d7cc;
    bytes32 constant ELE77 = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    uint256 constant LLTV_77 = 770000000000000000;
    uint256 constant LLTV_915 = 915000000000000000;

    function setUp() public {
        vm.createSelectFork(vm.envOr("RPC_URL", string("https://mainnet.base.org")));
    }

    function test_unwind_all_recovers_ele() public {
        uint256 ele0 = IERC20(ELE).balanceOf(HOT);
        uint256 usdc0 = IERC20(USDC).balanceOf(HOT);

        vm.startPrank(HOT);
        CrownForceShareUsdc helper = CrownForceShareUsdc(FORCE_HELPER);
        IMorpho(MORPHO).setAuthorization(address(helper), true);

        _force(helper, ORACLE_10, LLTV_915, TEN);
        _force(helper, ORACLE_77, LLTV_77, ELE77);

        IERC20(USDC).approve(MORPHO, type(uint256).max);
        _sweep(IMorpho.MarketParams(USDC, ELE, ORACLE_10, IRM, LLTV_915), TEN);
        _sweep(IMorpho.MarketParams(USDC, ELE, ORACLE_77, IRM, LLTV_77), ELE77);
        vm.stopPrank();

        uint256 ele1 = IERC20(ELE).balanceOf(HOT);
        uint256 usdc1 = IERC20(USDC).balanceOf(HOT);
        console2.log("ele0", ele0);
        console2.log("ele1", ele1);
        console2.log("usdc0", usdc0);
        console2.log("usdc1", usdc1);

        (, uint128 b1, uint128 c1) = IMorpho(MORPHO).position(TEN, HOT);
        (, uint128 b2, uint128 c2) = IMorpho(MORPHO).position(ELE77, HOT);
        assertEq(uint256(b1), 0, "ten debt");
        assertEq(uint256(b2), 0, "e77 debt");
        assertEq(uint256(c1), 0, "ten coll");
        assertEq(uint256(c2), 0, "e77 coll");
        assertGt(ele1, ele0 + 80_000_000e8, "ele recovered");
    }

    function _force(CrownForceShareUsdc helper, address oracle, uint256 lltv, bytes32 id) internal {
        IMorpho.MarketParams memory mp = IMorpho.MarketParams(USDC, ELE, oracle, IRM, lltv);
        IMorpho(MORPHO).accrueInterest(mp);
        (uint256 sup, uint128 bor,) = IMorpho(MORPHO).position(id, HOT);
        if (bor == 0 || sup == 0) return;
        (uint128 sa, uint128 ss, uint128 ba, uint128 bs,,) = IMorpho(MORPHO).market(id);
        uint256 debt = (uint256(bor) * uint256(ba) + uint256(bs) - 1) / uint256(bs);
        uint256 supplyAssets = (sup * uint256(sa)) / uint256(ss);
        uint256 flash = debt < supplyAssets ? debt : supplyAssets;
        flash -= 10;
        helper.forceMorphoSupply(
            CrownForceShareUsdc.MarketParams(USDC, ELE, oracle, IRM, lltv), flash, HOT
        );
    }

    function _sweep(IMorpho.MarketParams memory mp, bytes32 id) internal {
        IMorpho(MORPHO).accrueInterest(mp);
        (uint256 sup, uint128 bor, uint128 coll) = IMorpho(MORPHO).position(id, HOT);
        if (bor > 0) {
            IMorpho(MORPHO).repay(mp, 0, bor, HOT, "");
            (sup,, coll) = IMorpho(MORPHO).position(id, HOT);
        }
        if (sup > 0) {
            IMorpho(MORPHO).withdraw(mp, 0, sup, HOT, HOT);
            (,, coll) = IMorpho(MORPHO).position(id, HOT);
        }
        if (coll > 0) IMorpho(MORPHO).withdrawCollateral(mp, uint256(coll), HOT, HOT);
    }
}
