// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownGateV2} from "../src/CrownGateV2.sol";
import {CrownZkAutoDraw} from "../src/zk/CrownZkAutoDraw.sol";
import {CrownZkCredit} from "../src/zk/CrownZkCredit.sol";
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

interface IZkT {
    function isProven(address subject) external view returns (bool);
}

interface IERC20T {
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

contract MockZkGateFalse {
    function isProven(address) external pure returns (bool) {
        return false;
    }

    function attestations(address) external pure returns (uint256, uint256, bool) {
        return (0, 0, false);
    }
}

contract MockZkGateTrue {
    function isProven(address) external pure returns (bool) {
        return true;
    }

    function attestations(address) external pure returns (uint256, uint256, bool) {
        return (700_000e6, 1, true);
    }
}

/// @notice Fork: ZK-mandatory CrownGateV2 + AutoDraw against sovereign market.
contract SimCrownGateV2 is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address constant LIVE_GATE = 0x76fa390951fA31185490378F46B6e9F05bA4bC3b;
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant RSS = 0x7a305D07B537359cf468eAea9bb176E5308bC337;
    address constant SOV_ORACLE = 0x22E2F66a26eA8d01E0Bb4154ef4DfB0304a34f2d;
    address constant IRM = 0x46415998764C29aB2a25CbeA6254146D50D22687;
    address constant ZK_WALLET_GATE = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    uint256 constant LLTV = 770000000000000000;
    bytes32 constant SOV =
        0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b;

    function setUp() public {
        string memory rpc = vm.envOr("BASE_RPC_URL", vm.envOr("BASE_RPC", string("")));
        vm.createSelectFork(rpc);
    }

    function test_live_zk_proven_hot() public view {
        assertTrue(IZkT(ZK_WALLET_GATE).isProven(HOT), "HOT must be ZK-proven on Base port gate");
    }

    function test_live_zk_proven_safe_king() public view {
        CrownGateV2 gate = CrownGateV2(payable(LIVE_GATE));
        assertEq(gate.king(), SAFE, "Safe is King");
        assertEq(gate.pendingKing(), address(0), "no pending king");
        assertTrue(gate.operator(HOT), "HOT is operator");
        assertTrue(IZkT(ZK_WALLET_GATE).isProven(SAFE), "isProven(Safe) required for whenZkFire");
    }

    function test_live_market_params() public view {
        CrownGateV2 gate = CrownGateV2(payable(LIVE_GATE));
        assertEq(gate.MARKET_ID(), SOV);
        assertEq(gate.loanToken(), USDC);
        assertEq(gate.collateralToken(), RSS);
        assertEq(gate.oracle(), SOV_ORACLE);
        assertEq(gate.irm(), IRM);
        assertEq(gate.lltv(), LLTV);
        assertEq(address(gate.zkGate()), ZK_WALLET_GATE);
        assertFalse(gate.paused());
    }

    function test_reverts_without_zk() public {
        MockZkGateFalse bad = new MockZkGateFalse();
        IMorphoMarket.MarketParams memory mp =
            IMorphoMarket.MarketParams(USDC, RSS, SOV_ORACLE, IRM, LLTV);
        CrownGateV2 gate = new CrownGateV2(HOT, address(bad), mp, address(0));
        vm.prank(HOT);
        vm.expectRevert(CrownGateV2.NotProven.selector);
        gate.supplyCollateral(1);
        vm.prank(HOT);
        vm.expectRevert(CrownGateV2.NotProven.selector);
        gate.borrowUSDC(1, HOT);
    }

    function test_zk_adopt_and_shielded_autodraw() public {
        assertTrue(IZkT(ZK_WALLET_GATE).isProven(HOT));

        (, uint128 kingBor, uint128 kingColl) = IMorphoT(MORPHO).position(SOV, HOT);
        assertEq(kingBor, 0);
        assertGt(uint256(kingColl), 0);

        IMorphoMarket.MarketParams memory mp =
            IMorphoMarket.MarketParams(USDC, RSS, SOV_ORACLE, IRM, LLTV);

        // Fresh local credit + true zk for credit leg; Morpho gate uses LIVE port zkGate.
        MockZkGateTrue zkLocal = new MockZkGateTrue();
        CrownZkCredit credit = new CrownZkCredit(USDC, address(zkLocal), HOT, HOT, HOT);
        deal(USDC, address(this), 50_000e6);
        IERC20T(USDC).approve(address(credit), 50_000e6);
        credit.supply(50_000e6);

        vm.startPrank(HOT);
        CrownGateV2 gate = new CrownGateV2(HOT, ZK_WALLET_GATE, mp, HOT);
        CrownZkAutoDraw autoDraw = new CrownZkAutoDraw(ZK_WALLET_GATE, address(gate), address(credit), HOT, HOT, HOT);
        gate.setOperator(address(autoDraw), true);
        credit.setOperator(address(autoDraw), true);

        IMorphoT.MarketParams memory mpf =
            IMorphoT.MarketParams(USDC, RSS, SOV_ORACLE, IRM, LLTV);
        IMorphoT(MORPHO).withdrawCollateral(mpf, uint256(kingColl), HOT, HOT);
        IERC20T(RSS).approve(address(gate), uint256(kingColl));
        gate.supplyCollateral(uint256(kingColl)); // live ZK required
        vm.stopPrank();

        (, uint128 gBor, uint128 gColl) = IMorphoT(MORPHO).position(SOV, address(gate));
        assertEq(uint256(gColl), uint256(kingColl));
        assertEq(gBor, 0);

        uint256 seed = 1_000_000e6;
        deal(USDC, address(this), seed);
        IERC20T(USDC).approve(MORPHO, seed);
        IMorphoT(MORPHO).supply(mpf, seed, 0, address(this), "");

        uint256 morphoBorrow = 100_000e6;
        uint256 creditBorrow = 10_000e6;
        uint256 hotBefore = IERC20T(USDC).balanceOf(HOT);

        vm.prank(HOT);
        autoDraw.autoDraw(morphoBorrow, HOT, creditBorrow);

        assertEq(IERC20T(USDC).balanceOf(HOT) - hotBefore, morphoBorrow + creditBorrow);
        (, uint128 gBor2,) = IMorphoT(MORPHO).position(SOV, address(gate));
        assertGt(uint256(gBor2), 0);
        assertEq(credit.debtOf(HOT), creditBorrow);

        console2.log("gateColl", uint256(gColl));
        console2.log("morphoBorrow", morphoBorrow);
        console2.log("creditBorrow", creditBorrow);
        console2.log("ZK_SHIELD", uint256(1));
    }

    function test_only_king() public {
        IMorphoMarket.MarketParams memory mp =
            IMorphoMarket.MarketParams(USDC, RSS, SOV_ORACLE, IRM, LLTV);
        CrownGateV2 gate = new CrownGateV2(HOT, ZK_WALLET_GATE, mp, HOT);
        vm.expectRevert(CrownGateV2.NotKing.selector);
        gate.borrowUSDC(1, address(this));
    }

    /// @notice Safe King: HOT operator cannot pause; only King controls pause.
    function test_safe_king_hot_cannot_pause() public {
        CrownGateV2 gate = CrownGateV2(payable(LIVE_GATE));
        assertEq(gate.king(), SAFE);
        assertTrue(gate.operator(HOT));

        vm.prank(HOT);
        vm.expectRevert(CrownGateV2.NotKing.selector);
        gate.setPaused(true);

        console2.log("SAFE_KING_HOT_CANNOT_PAUSE", uint256(1));
    }

    /// @notice Live gate kill switch under Safe king (fork prank as Safe).
    function test_live_gate_kill_switch() public {
        CrownGateV2 gate = CrownGateV2(payable(LIVE_GATE));
        assertEq(gate.king(), SAFE);
        assertTrue(IZkT(ZK_WALLET_GATE).isProven(SAFE));

        vm.prank(SAFE);
        gate.setPaused(true);
        assertTrue(gate.paused());

        vm.prank(HOT);
        vm.expectRevert(CrownGateV2.IsPaused.selector);
        gate.borrowUSDC(1, HOT);

        vm.prank(SAFE);
        gate.setPaused(false);
        assertFalse(gate.paused());

        console2.log("KILL_SWITCH", uint256(1));
    }

    /// @notice rescueToken blocks collateral; allows other tokens (fork).
    function test_rescue_blocks_collateral() public {
        CrownGateV2 gate = CrownGateV2(payable(LIVE_GATE));
        assertEq(gate.king(), SAFE);

        vm.prank(SAFE);
        vm.expectRevert(CrownGateV2.RescueBlocked.selector);
        gate.rescueToken(RSS, 1, SAFE);

        console2.log("RESCUE_BLOCKS_COLLATERAL", uint256(1));
    }

    /// @notice Only Safe King may initiate transfer; HOT cannot steal the throne.
    function test_only_safe_initiates_king_transfer() public {
        CrownGateV2 gate = CrownGateV2(payable(LIVE_GATE));
        assertEq(gate.king(), SAFE);

        vm.prank(HOT);
        vm.expectRevert(CrownGateV2.NotKing.selector);
        gate.initiateKingTransfer(HOT);

        vm.prank(SAFE);
        gate.initiateKingTransfer(NEW_COLD);
        assertEq(gate.pendingKing(), NEW_COLD);

        // Cancel path: re-initiate to zero-safe holding — leave pending; do not accept (doctrine).
        // Clear by initiating back to Safe then accept as Safe (no HOT throne).
        vm.prank(SAFE);
        gate.initiateKingTransfer(SAFE);
        vm.prank(SAFE);
        gate.acceptKingship();
        assertEq(gate.king(), SAFE);
        assertEq(gate.pendingKing(), address(0));

        console2.log("KING_TRANSFER_CONTROLS", uint256(1));
    }

    address constant NEW_COLD = 0x5E07D7167282F9ec912a05c3048D7D0F24A8b826;
}
