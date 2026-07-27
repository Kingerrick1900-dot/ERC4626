// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownLeverageExtractor} from "../src/CrownLeverageExtractor.sol";

interface IYele {
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
    function deposit(uint256, address) external returns (uint256);
}

interface IMorpho {
    function setAuthorization(address, bool) external;
    function isAuthorized(address, address) external view returns (bool);
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

/// @dev yELE asset = USDC. Path: acceptCap → deposit USDC on WETH → curator realloc → borrow Landing.
contract DiskFillWarped is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LAND = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant YELE = 0x61bfD6F7df1f72427F472144d043c25d742D145E;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant WETH_ORACLE = 0xFEa2D58cEfCb9fcb597723c6bAE66fFE4193aFE4;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    bytes32 constant WETH_USDC = 0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;
    uint256 constant LLTV_86 = 860000000000000000;
    uint256 constant ASK = 700_000e6;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_RPC", string("https://mainnet.base.org")));
    }

    function test_curator_disk_fill_700k() public {
        vm.warp(1785092927 + 10);
        vm.startPrank(HOT);

        IYele(YELE).acceptCap(IYele.MarketParams(USDC, WETH, WETH_ORACLE, IRM, LLTV_86));
        bytes32[] memory q = new bytes32[](2);
        q[0] = WETH_USDC;
        q[1] = ELE_USDC;
        IYele(YELE).setSupplyQueue(q);

        deal(USDC, HOT, ASK);
        IERC20(USDC).approve(YELE, type(uint256).max);
        IYele(YELE).deposit(ASK, HOT);

        (uint256 wSup,,) = IMorpho(MORPHO).position(WETH_USDC, YELE);
        require(wSup > 0, "no weth supply");

        CrownLeverageExtractor x = new CrownLeverageExtractor(HOT, LAND);
        if (!IMorpho(MORPHO).isAuthorized(HOT, address(x))) {
            IMorpho(MORPHO).setAuthorization(address(x), true);
        }
        IYele(YELE).setIsAllocator(address(x), true);

        uint256 landBefore = IERC20(USDC).balanceOf(LAND);
        x.curatorDiskFill(ASK);
        uint256 delta = IERC20(USDC).balanceOf(LAND) - landBefore;
        console2.log("landDelta", delta);
        assertGe(delta, ASK - 1e6, "700k");
        vm.stopPrank();
    }

    /// @dev Path A: external USDC → yELE → ELE77 idle → live extractor borrowIdle → Landing $500k.
    ///      No new builds. Depositor ≠ hot recycle.
    function test_landing_500k_borrowIdle_external_deposit() public {
        address extractor = 0x5d99EEf1954053EDc4D73ba1429E51DaC539bf58;
        address whale = address(0xBEEF);
        uint256 ask = 500_000e6;

        // External depositor (not hot) seeds yELE → ELE77 idle.
        deal(USDC, whale, ask);
        vm.startPrank(whale);
        IERC20(USDC).approve(YELE, ask);
        IYele(YELE).deposit(ask, whale);
        vm.stopPrank();

        vm.startPrank(HOT);
        if (!IMorpho(MORPHO).isAuthorized(HOT, extractor)) {
            IMorpho(MORPHO).setAuthorization(extractor, true);
        }
        uint256 landBefore = IERC20(USDC).balanceOf(LAND);
        CrownLeverageExtractor(payable(extractor)).borrowIdle(ask);
        uint256 delta = IERC20(USDC).balanceOf(LAND) - landBefore;
        console2.log("land500kDelta", delta);
        assertGe(delta, ask - 1e6, "500k");
        vm.stopPrank();
    }
}
