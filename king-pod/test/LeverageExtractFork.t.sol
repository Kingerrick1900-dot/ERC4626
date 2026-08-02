// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownLeverageExtractor} from "../src/CrownLeverageExtractor.sol";

interface IMorphoT {
    function setAuthorization(address, bool) external;
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IPafT {
    function flowCaps(address vault, bytes32 id) external view returns (uint128 maxIn, uint128 maxOut);
}

interface IMetaT {
    function config(bytes32) external view returns (uint184 cap, bool enabled, uint64 removableAt);
    function totalAssets() external view returns (uint256);
}

interface IZkT {
    function isProven(address) external view returns (bool);
}

interface IExtractorT {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function wethUsdcParams() external view returns (MarketParams memory);
    function reallocateAndBorrow(address vault, MarketParams calldata from, uint128 pull, uint256 borrowAmt)
        external
        payable;
    function borrowIdle(uint256 borrowAmt) external;
}

/// @dev Proves: yELE maxIn=$700k ≠ extractable; PA from WETH source reverts; idle borrow may dust.
contract LeverageExtractForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant PA = 0xA090dD1a701408Df1d4d0B85b716c87565f90467;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    bytes32 constant WETH_USDC = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC", string("https://mainnet.base.org")));
    }

    function test_yele_maxIn_is_not_weth_liquidity() public view {
        (uint128 maxIn,) = IPafT(PA).flowCaps(YELE, ELE_USDC);
        (, bool wethOn,) = IMetaT(YELE).config(WETH_USDC);
        (uint256 wethSup,,) = IMorphoT(MORPHO).position(WETH_USDC, YELE);
        console2.log("maxIn", uint256(maxIn));
        console2.log("yeleTA", IMetaT(YELE).totalAssets());
        console2.log("wethEnabled", wethOn ? uint256(1) : uint256(0));
        console2.log("yeleWethSupShares", wethSup);
        assertEq(uint256(maxIn), 700_000e6, "cap");
        assertFalse(wethOn, "weth cap live");
        assertEq(wethSup, 0, "no weth supply");
    }

    function test_pa_yele_weth_to_ele_700k_reverts() public {
        require(IZkT(GATE).isProven(HOT), "gate");
        vm.startPrank(HOT);
        CrownLeverageExtractor x = new CrownLeverageExtractor(HOT, LAND);
        IMorphoT(MORPHO).setAuthorization(address(x), true);
        IExtractorT.MarketParams memory from = IExtractorT(address(x)).wethUsdcParams();
        vm.expectRevert();
        IExtractorT(address(x)).reallocateAndBorrow(YELE, from, uint128(700_000e6), 0);
        vm.stopPrank();
    }

    function test_borrow_idle_dust_ok() public {
        require(IZkT(GATE).isProven(HOT), "gate");
        (uint128 sa,, uint128 ba,,,) = IMorphoT(MORPHO).market(ELE_USDC);
        uint256 idle = uint256(sa) > uint256(ba) ? uint256(sa) - uint256(ba) : 0;
        console2.log("idle", idle);
        if (idle <= 1e6) {
            console2.log("SKIP_NO_IDLE", uint256(1));
            return;
        }
        vm.startPrank(HOT);
        CrownLeverageExtractor x = new CrownLeverageExtractor(HOT, LAND);
        IMorphoT(MORPHO).setAuthorization(address(x), true);
        x.borrowIdle(0);
        vm.stopPrank();
    }
}
