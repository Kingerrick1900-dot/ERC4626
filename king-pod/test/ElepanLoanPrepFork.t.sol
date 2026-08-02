// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownElepanPreSelfLiq} from "../src/CrownElepanPreSelfLiq.sol";
import {CrownElepanKeepDraw} from "../src/CrownElepanKeepDraw.sol";
import {CrownMorphoZkPack} from "../src/CrownMorphoZkPack.sol";

interface IERC20T {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IMorphoT {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function setAuthorization(address, bool) external;
    function position(bytes32, address) external view returns (uint256, uint128, uint128);
}

interface IZkGateT {
    function isProven(address) external view returns (bool);
}

/// @notice Fork prep: ZK-gated KEEP loan + portion + self-liq. No mainnet broadcast.
contract ElepanLoanPrepFork is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant ELEPAN = 0x50639C42E2FFDEC4F68FB468968a55b3Af944583;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant GATE = 0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30;
    address constant CREDIT = 0xc4152c73824d85146B0f85a0b77E911D4769d936;
    address constant ORACLE = 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant ELE_USDC = 0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc;

    function setUp() public {
        string memory rpc = vm.envOr("BASE_RPC", string("https://mainnet.base.org"));
        vm.createSelectFork(rpc);
        require(IZkGateT(GATE).isProven(HOT), "fork needs proven hot");
    }

    function test_prep_keep_then_selfLiq_modeA() public {
        deal(USDC, HOT, 100_000e6);
        deal(ELEPAN, HOT, 200_000e8);

        vm.startPrank(HOT);

        CrownElepanKeepDraw keep = new CrownElepanKeepDraw(
            GATE, MORPHO, USDC, ELEPAN, HOT, LANDING, ELE_USDC, ORACLE, IRM, LLTV, HOT
        );
        CrownElepanPreSelfLiq selfLiq = new CrownElepanPreSelfLiq(
            GATE, MORPHO, USDC, ELEPAN, HOT, LANDING, ELE_USDC, ORACLE, IRM, LLTV, HOT
        );

        IMorphoT(MORPHO).setAuthorization(address(keep), true);
        IMorphoT(MORPHO).setAuthorization(address(selfLiq), true);

        IERC20T(USDC).approve(address(keep), type(uint256).max);
        IERC20T(ELEPAN).approve(address(keep), type(uint256).max);

        uint256 landBefore = IERC20T(USDC).balanceOf(LANDING);
        keep.drawKeep(50_000e6, 200_000e8, 40_000e6);
        assertEq(IERC20T(USDC).balanceOf(LANDING) - landBefore, 40_000e6, "KEEP portion");

        uint256 eleLandBefore = IERC20T(ELEPAN).balanceOf(LANDING);
        selfLiq.selfLiquidate();

        (, uint128 bor2, uint128 coll2) = IMorphoT(MORPHO).position(ELE_USDC, HOT);
        assertEq(uint256(bor2), 0, "debt cleared");
        assertEq(uint256(coll2), 0, "coll cleared");
        assertGt(IERC20T(ELEPAN).balanceOf(LANDING), eleLandBefore, "ELE to Landing");

        vm.stopPrank();
        console2.log("FORK_PREP_SELF_LIQ_OK", uint256(1));
    }

    function test_prep_borrowPortion_and_zkBook() public {
        deal(USDC, HOT, 100_000e6);
        deal(ELEPAN, HOT, 200_000e8);

        vm.startPrank(HOT);
        CrownMorphoZkPack book = new CrownMorphoZkPack(
            GATE, CREDIT, MORPHO, USDC, ELEPAN, HOT, LANDING, ELE_USDC, ORACLE, LLTV, HOT
        );
        CrownElepanKeepDraw keep = new CrownElepanKeepDraw(
            GATE, MORPHO, USDC, ELEPAN, HOT, LANDING, ELE_USDC, ORACLE, IRM, LLTV, HOT
        );
        CrownElepanPreSelfLiq selfLiq = new CrownElepanPreSelfLiq(
            GATE, MORPHO, USDC, ELEPAN, HOT, LANDING, ELE_USDC, ORACLE, IRM, LLTV, HOT
        );
        keep.setOperator(address(book));
        selfLiq.setOperator(address(book));
        book.wire(address(keep), address(selfLiq));

        IMorphoT(MORPHO).setAuthorization(address(keep), true);
        IERC20T(USDC).approve(address(keep), type(uint256).max);
        IERC20T(ELEPAN).approve(address(keep), type(uint256).max);

        keep.drawKeep(80_000e6, 200_000e8, 30_000e6);
        uint256 land1 = IERC20T(USDC).balanceOf(LANDING);

        // Same loan second portion via ZK book
        book.borrowPortionZk(20_000e6);
        assertEq(IERC20T(USDC).balanceOf(LANDING) - land1, 20_000e6, "zk portion");

        (bool proven, uint256 attest,,,,,,,) = book.book();
        assertTrue(proven, "proven");
        assertGe(attest, 700_000e6, "attest");

        vm.stopPrank();
        console2.log("FORK_MORPHO_ZK_PACK_OK", uint256(1));
    }
}
