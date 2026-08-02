// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownExitLadder} from "../src/CrownExitLadder.sol";

interface IMorphoT {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function setAuthorization(address, bool) external;
    function supply(MarketParams memory, uint256, uint256, address, bytes memory) external returns (uint256, uint256);
    function market(bytes32) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
}

interface IYeleT {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function acceptCap(MarketParams calldata) external;
    function setSupplyQueue(bytes32[] calldata) external;
    function setIsAllocator(address, bool) external;
}

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

contract ExitLadderForkTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant ELE = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant WETH_ORACLE = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    bytes32 constant WETH_USDC = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;
    uint256 constant ASK = 700_000e6;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC", string("https://mainnet.base.org")));
    }

    function test_drawIdle_without_liquidity_is_zero() public {
        vm.startPrank(HOT);
        CrownExitLadder x = new CrownExitLadder(HOT, LAND);
        IMorphoT(MORPHO).setAuthorization(address(x), true);
        uint256 landBefore = IERC20T(USDC).balanceOf(LAND);
        uint256 got = x.drawIdle(ASK);
        console2.log("got", got);
        assertEq(got, 0, "no fake borrow");
        assertEq(IERC20T(USDC).balanceOf(LAND), landBefore, "land");
        vm.stopPrank();
    }

    function test_leverageLoop_with_seeded_idle() public {
        vm.warp(1785092927 + 10);

        // Whale supplies idle — this is the missing Step-1 liquidity DeepSeek assumed.
        address whale = address(0xBEEF);
        deal(USDC, whale, ASK);
        vm.startPrank(whale);
        IERC20T(USDC).approve(MORPHO, ASK);
        IMorphoT(MORPHO).supply(
            IMorphoT.MarketParams(USDC, ELE, ORACLE, IRM, 770000000000000000), ASK, 0, whale, ""
        );
        vm.stopPrank();

        vm.startPrank(HOT);
        IYeleT(YELE).acceptCap(IYeleT.MarketParams(USDC, WETH, WETH_ORACLE, IRM, 860000000000000000));
        bytes32[] memory q = new bytes32[](2);
        q[0] = WETH_USDC;
        q[1] = ELE_USDC;
        IYeleT(YELE).setSupplyQueue(q);

        CrownExitLadder x = new CrownExitLadder(HOT, LAND);
        IMorphoT(MORPHO).setAuthorization(address(x), true);
        IYeleT(YELE).setIsAllocator(address(x), true);

        uint256 landBefore = IERC20T(USDC).balanceOf(LAND);
        uint256 landed = x.leverageLoop(ASK);
        console2.log("landed", landed);
        assertGe(landed, ASK - 1e6, "loop");
        assertGe(IERC20T(USDC).balanceOf(LAND) - landBefore, ASK - 1e6, "land");
        vm.stopPrank();
    }
}
