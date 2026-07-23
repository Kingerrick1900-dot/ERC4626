// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownElepanUsd} from "../src/CrownElepanUsd.sol";
import {CrownElepanCdpVault} from "../src/CrownElepanCdpVault.sol";
import {MockElepan8, MockElepanOracle, MockZkElepanGate} from "./mocks/MockElepanCdp.sol";

contract CrownElepanCdpVaultTest is Test {
    address internal king = makeAddr("king");
    MockElepan8 internal elepan;
    MockElepanOracle internal oracle;
    MockZkElepanGate internal zkGate;
    CrownElepanUsd internal eusd;
    CrownElepanCdpVault internal vault;

    uint256 constant LR = 1.5e18; // 150% liquidation ratio
    uint256 constant FLOOR = 1.55e18; // safety floor
    uint256 constant FEE_BPS = 500; // 5%/yr

    function setUp() public {
        vm.deal(king, 1 ether);
        elepan = new MockElepan8();
        oracle = new MockElepanOracle();
        zkGate = new MockZkElepanGate();
        zkGate.setProofTtl(0); // unit tests warp time for fee; production gate uses 7d TTL
        zkGate.setProven(king, true);
        eusd = new CrownElepanUsd(king);
        vault = new CrownElepanCdpVault(
            address(elepan),
            address(eusd),
            address(oracle),
            address(zkGate),
            king,
            king, // feeRecipient
            king, // treasury (Access Clause destination in unit tests)
            LR,
            FLOOR,
            FEE_BPS
        );
        vm.prank(king);
        eusd.setMinter(address(vault), true);

        // 100M Elepan (8dp)
        elepan.mint(king, 100_000_000e8);
        vm.prank(king);
        elepan.approve(address(vault), type(uint256).max);
    }

    function test_deposit_mint_hf() public {
        vm.startPrank(king);
        vault.deposit(30_000_000e8); // $30M soft
        vault.mint(10_000_000e18); // $10M eUSD → HF = 3.0
        vm.stopPrank();
        assertEq(vault.coll(), 30_000_000e8);
        assertEq(eusd.balanceOf(king), 10_000_000e18);
        assertGt(vault.healthFactor(), FLOOR);
    }

    /// @notice CRITICAL build verification: partial withdraw while debt open.
    function test_partial_withdraw_keeps_hf_above_floor() public {
        vm.startPrank(king);
        vault.deposit(40_000_000e8); // $40M
        vault.mint(14_000_000e18); // $14M → HF ≈ 2.857
        uint256 hfBefore = vault.healthFactor();
        assertGt(hfBefore, FLOOR);

        // Withdraw $10M Elepan → coll $30M, debt $14M → HF ≈ 2.143 ≥ 1.55
        uint256 preview = vault.previewWithdrawHf(10_000_000e8);
        assertGe(preview, FLOOR);
        vault.withdraw(10_000_000e8);
        vm.stopPrank();

        assertEq(vault.coll(), 30_000_000e8);
        assertEq(elepan.balanceOf(king), 70_000_000e8); // 100M - 30M left in vault
        assertGe(vault.healthFactor(), FLOOR);
        assertEq(eusd.balanceOf(king), 14_000_000e18); // debt unchanged
    }

    function test_partial_withdraw_reverts_below_floor() public {
        vm.startPrank(king);
        vault.deposit(22_000_000e8); // $22M
        vault.mint(14_000_000e18); // HF ≈ 1.571
        // Withdraw too much → HF < 1.55
        vm.expectRevert(CrownElepanCdpVault.UnsafeHf.selector);
        vault.withdraw(1_000_000e8);
        vm.stopPrank();
    }

    function test_full_repay_unlocks_all_collateral() public {
        vm.startPrank(king);
        vault.deposit(25_000_000e8);
        vault.mint(10_000_000e18);
        vault.repay(10_000_000e18);
        assertEq(vault.accruedDebt(), 0);
        vault.withdraw(25_000_000e8); // full unlock — no debt
        vm.stopPrank();
        assertEq(vault.coll(), 0);
        assertEq(elepan.balanceOf(king), 100_000_000e8);
    }

    function test_close_repays_and_returns_all() public {
        vm.startPrank(king);
        vault.deposit(25_000_000e8);
        vault.mint(8_000_000e18);
        vault.close();
        vm.stopPrank();
        assertEq(vault.coll(), 0);
        assertEq(vault.debt(), 0);
        assertEq(elepan.balanceOf(king), 100_000_000e8);
    }

    function test_stability_fee_accrues() public {
        vm.startPrank(king);
        vault.deposit(30_000_000e8);
        vault.mint(10_000_000e18);
        vm.stopPrank();
        uint256 d0 = vault.accruedDebt();
        uint256 bal0 = eusd.balanceOf(king);
        vm.warp(block.timestamp + 365 days);
        vault.accrue();
        uint256 d1 = vault.accruedDebt();
        // ~5% on 10M ≈ 500k (linear approx)
        assertGt(d1, d0);
        assertApproxEqRel(d1 - d0, 500_000e18, 0.02e18); // within 2%
        // Fee eUSD minted to feeRecipient (king) so close/repay stays solvent
        assertEq(eusd.balanceOf(king) - bal0, d1 - d0);
    }

    function test_close_after_fee_accrual() public {
        vm.startPrank(king);
        vault.deposit(25_000_000e8);
        vault.mint(8_000_000e18);
        vm.warp(block.timestamp + 30 days);
        vault.close(); // accrue mints fee to king, then burns all debt
        vm.stopPrank();
        assertEq(vault.coll(), 0);
        assertEq(vault.accruedDebt(), 0);
        assertEq(elepan.balanceOf(king), 100_000_000e8);
        assertEq(eusd.balanceOf(king), 0);
    }

    function test_maxWithdrawable_matches_partial_path() public {
        vm.startPrank(king);
        vault.deposit(40_000_000e8);
        vault.mint(14_000_000e18);
        uint256 maxW = vault.maxWithdrawable();
        assertGt(maxW, 0);
        vault.withdraw(maxW);
        // next unit should revert
        if (vault.coll() > 0 && vault.accruedDebt() > 0) {
            vm.expectRevert(CrownElepanCdpVault.UnsafeHf.selector);
            vault.withdraw(1);
        }
        vm.stopPrank();
        assertGe(vault.healthFactor(), FLOOR);
    }

    function test_only_king() public {
        address rando = address(0xBEEF);
        zkGate.setProven(rando, true);
        vm.expectRevert();
        vm.prank(rando);
        vault.deposit(1e8);
    }

    function test_requires_zk_proven() public {
        zkGate.setProven(king, false);
        vm.startPrank(king);
        vm.expectRevert(MockZkElepanGate.Expired.selector);
        vault.deposit(1e8);
        vm.stopPrank();
    }

    /// @notice Wrong mint recipient must revert — debt must not open off cold treasury.
    function test_mintTo_non_treasury_reverts_cold_miss() public {
        address notCold = makeAddr("notCold");
        vm.startPrank(king);
        vault.deposit(30_000_000e8);
        vm.expectRevert(CrownElepanCdpVault.ColdMiss.selector);
        vault.mintTo(notCold, 1_000_000e18);
        vm.stopPrank();
        assertEq(vault.debt(), 0);
        assertEq(eusd.balanceOf(notCold), 0);
        assertEq(eusd.balanceOf(address(vault)), 0);
    }

    function test_mint_credits_treasury_vault_holds_zero() public {
        address cold = makeAddr("cold");
        CrownElepanCdpVault v = new CrownElepanCdpVault(
            address(elepan), address(eusd), address(oracle), address(zkGate), king, king, cold, LR, FLOOR, FEE_BPS
        );
        vm.prank(king);
        eusd.setMinter(address(v), true);
        vm.startPrank(king);
        elepan.approve(address(v), type(uint256).max);
        v.deposit(30_000_000e8);
        v.mint(10_000_000e18);
        vm.stopPrank();
        assertEq(eusd.balanceOf(cold), 10_000_000e18);
        assertEq(eusd.balanceOf(address(v)), 0);
        assertEq(eusd.balanceOf(king), 0);
    }

    function test_selfLiquidate_reverts_when_healthy() public {
        vm.startPrank(king);
        vault.deposit(30_000_000e8);
        vault.mint(10_000_000e18); // HF 3.0
        assertFalse(vault.liquidatable());
        vm.expectRevert(CrownElepanCdpVault.NotLiquidatable.selector);
        vault.selfLiquidate();
        vm.stopPrank();
    }

    function test_selfLiquidate_clears_underwater_position() public {
        address cold = makeAddr("cold");
        CrownElepanCdpVault v = new CrownElepanCdpVault(
            address(elepan), address(eusd), address(oracle), address(zkGate), king, king, cold, LR, FLOOR, FEE_BPS
        );
        vm.prank(king);
        eusd.setMinter(address(v), true);
        vm.startPrank(king);
        elepan.approve(address(v), type(uint256).max);
        v.deposit(20_000_000e8);
        v.mint(12_000_000e18); // HF ≈ 1.666 at $1 — above floor 1.55, above LR 1.50
        vm.stopPrank();
        // Crash oracle soft price → HF < 150%
        oracle.setPrice(0.8e34); // $0.80
        assertTrue(v.liquidatable());
        uint256 coldBefore = eusd.balanceOf(cold);
        uint256 eleBefore = elepan.balanceOf(king);
        vm.prank(king);
        v.selfLiquidate();
        assertEq(v.debt(), 0);
        assertEq(v.coll(), 0);
        assertEq(eusd.balanceOf(cold), coldBefore - 12_000_000e18);
        assertEq(elepan.balanceOf(king), eleBefore + 20_000_000e8);
        assertFalse(v.liquidatable());
    }
}
