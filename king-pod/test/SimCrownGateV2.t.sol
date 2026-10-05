// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownGateV2} from "../src/CrownGateV2.sol";
import {IMorphoMarket} from "../src/interfaces/IMorphoMarket.sol";

interface IMorphoT {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function position(bytes32 id, address user) external view returns (uint256, uint128, uint128);
    function market(bytes32 id) external view returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function withdrawCollateral(MarketParams memory marketParams, uint256 assets, address onBehalf, address receiver)
        external;
    function supply(MarketParams memory marketParams, uint256 assets, uint256 shares, address onBehalf, bytes memory data)
        external
        returns (uint256, uint256);
    function idToMarketParams(bytes32 id)
        external
        view
        returns (address, address, address, address, uint256);
}

interface IERC20T {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

/// @notice Fork: adopt King's sovereign RSS onto CrownGateV2 and borrow against $50k oracle.
contract SimCrownGateV2 is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant SOV_ORACLE = 0x22E2F66a26eA8d01E0Bb4154ef4DfB0304a34f2d;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant SOV =
        0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b;

    function setUp() public {
        string memory rpc = vm.envOr("BASE_RPC_URL", vm.envOr("BASE_RPC", string("")));
        vm.createSelectFork(rpc);
    }

    function test_adopt_and_borrow_against_sovereign() public {
        (address loan, address coll, address orc,,) = IMorphoT(MORPHO).idToMarketParams(SOV);
        assertEq(loan, USDC);
        assertEq(coll, RSS);
        assertEq(orc, SOV_ORACLE);

        (, uint128 kingBor, uint128 kingColl) = IMorphoT(MORPHO).position(SOV, HOT);
        assertEq(kingBor, 0);
        assertGt(uint256(kingColl), 0);

        IMorphoMarket.MarketParams memory mp =
            IMorphoMarket.MarketParams(USDC, RSS, SOV_ORACLE, IRM, LLTV);
        assertEq(keccak256(abi.encode(mp)), SOV);

        vm.startPrank(HOT);
        CrownGateV2 gate = new CrownGateV2(HOT, mp);

        IMorphoT.MarketParams memory mpf =
            IMorphoT.MarketParams(USDC, RSS, SOV_ORACLE, IRM, LLTV);
        IMorphoT(MORPHO).withdrawCollateral(mpf, uint256(kingColl), HOT, HOT);
        IERC20T(RSS).approve(address(gate), uint256(kingColl));
        gate.supplyCollateral(uint256(kingColl));
        vm.stopPrank();

        (, uint128 gBor, uint128 gColl) = IMorphoT(MORPHO).position(SOV, address(gate));
        assertEq(uint256(gColl), uint256(kingColl));
        assertEq(gBor, 0);

        // Seed market cash so borrow is possible (sovereign book may be empty of suppliers).
        uint256 seed = 1_000_000e6;
        deal(USDC, address(this), seed);
        IERC20T(USDC).approve(MORPHO, seed);
        IMorphoT(MORPHO).supply(mpf, seed, 0, address(this), "");

        uint256 borrowAmt = 100_000e6;
        uint256 hotBefore = IERC20T(USDC).balanceOf(HOT);
        vm.prank(HOT);
        gate.borrowUSDC(borrowAmt, HOT);
        assertEq(IERC20T(USDC).balanceOf(HOT) - hotBefore, borrowAmt);

        (, uint128 gBor2,) = IMorphoT(MORPHO).position(SOV, address(gate));
        assertGt(uint256(gBor2), 0);
        console2.log("gateColl", uint256(gColl));
        console2.log("borrowed", borrowAmt);
    }

    function test_only_king() public {
        IMorphoMarket.MarketParams memory mp =
            IMorphoMarket.MarketParams(USDC, RSS, SOV_ORACLE, IRM, LLTV);
        CrownGateV2 gate = new CrownGateV2(HOT, mp);
        vm.expectRevert(CrownGateV2.NotKing.selector);
        gate.borrowUSDC(1, address(this));
    }
}
