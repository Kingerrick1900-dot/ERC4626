// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownElepanUsd} from "../src/CrownElepanUsd.sol";
import {CrownAssetCdpVault} from "../src/CrownAssetCdpVault.sol";
import {CrownWethCdpVault} from "../src/CrownWethCdpVault.sol";
import {CrownCbbtcCdpVault} from "../src/CrownCbbtcCdpVault.sol";
import {MockZkElepanGate} from "./mocks/MockElepanCdp.sol";

contract MockErc20Dec {
    uint8 public immutable decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(uint8 d) {
        decimals = d;
    }

    function mint(address to, uint256 amt) external {
        totalSupply += amt;
        balanceOf[to] += amt;
    }

    function approve(address s, uint256 a) external returns (bool) {
        allowance[msg.sender][s] = a;
        return true;
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        return true;
    }

    function transferFrom(address f, address t, uint256 amt) external returns (bool) {
        uint256 a = allowance[f][msg.sender];
        if (a != type(uint256).max) allowance[f][msg.sender] = a - amt;
        balanceOf[f] -= amt;
        balanceOf[t] += amt;
        return true;
    }
}

contract MockMorphoUsdOracle {
    uint256 public price;

    constructor(uint256 p) {
        price = p;
    }

    function setPrice(uint256 p) external {
        price = p;
    }
}

/// @dev Test harness exposing CrownAssetCdpVault with arbitrary collateral.
contract HarnessAssetCdp is CrownAssetCdpVault {
    constructor(
        address coll,
        address eusd,
        address oracle,
        address zk,
        address king,
        uint256 lr,
        uint256 floor,
        uint256 feeBps
    ) CrownAssetCdpVault(coll, eusd, oracle, zk, king, king, lr, floor, feeBps) {}
}

contract CrownWethCdpVaultTest is Test {
    address internal king = makeAddr("king");
    MockErc20Dec internal weth;
    MockMorphoUsdOracle internal oracle;
    MockZkElepanGate internal zkGate;
    CrownElepanUsd internal eusd;
    HarnessAssetCdp internal vault;

    uint256 constant LR = 1.3e18;
    uint256 constant FLOOR = 1.35e18;
    uint256 constant FEE_BPS = 500;
    // $2000 WETH → morpho price = 2000e6 * 1e36 / 1e18 = 2e27
    uint256 constant PX = 2e27;

    function setUp() public {
        weth = new MockErc20Dec(18);
        oracle = new MockMorphoUsdOracle(PX);
        zkGate = new MockZkElepanGate();
        zkGate.setProven(king, true);
        eusd = new CrownElepanUsd(king);
        vault = new HarnessAssetCdp(address(weth), address(eusd), address(oracle), address(zkGate), king, LR, FLOOR, FEE_BPS);
        vm.prank(king);
        eusd.setMinter(address(vault), true);
        weth.mint(king, 100 ether);
        vm.prank(king);
        weth.approve(address(vault), type(uint256).max);
    }

    function test_wrapper_binds_weth() public {
        CrownWethCdpVault v = new CrownWethCdpVault(
            address(eusd), address(oracle), address(zkGate), king, king, LR, FLOOR, FEE_BPS
        );
        assertEq(address(v.collateral()), v.WETH());
        assertEq(v.WETH(), 0x4200000000000000000000000000000000000006);
    }

    function test_deposit_mint_hf() public {
        vm.startPrank(king);
        vault.deposit(10 ether);
        vault.mint(10_000e18); // HF = 2.0
        vm.stopPrank();
        assertEq(vault.coll(), 10 ether);
        assertEq(eusd.balanceOf(king), 10_000e18);
        assertGe(vault.healthFactor(), FLOOR);
    }

    function test_partial_withdraw_keeps_hf_above_floor() public {
        vm.startPrank(king);
        vault.deposit(20 ether);
        vault.mint(20_000e18);
        vault.withdraw(5 ether);
        vm.stopPrank();
        assertEq(vault.coll(), 15 ether);
        assertGe(vault.healthFactor(), FLOOR);
    }

    function test_partial_withdraw_reverts_below_floor() public {
        vm.startPrank(king);
        vault.deposit(14 ether);
        vault.mint(20_000e18);
        vm.expectRevert(CrownAssetCdpVault.UnsafeHf.selector);
        vault.withdraw(2 ether);
        vm.stopPrank();
    }

    function test_full_repay_unlocks_all() public {
        vm.startPrank(king);
        vault.deposit(10 ether);
        vault.mint(5_000e18);
        vault.repay(5_000e18);
        vault.withdraw(10 ether);
        vm.stopPrank();
        assertEq(vault.coll(), 0);
    }

    function test_close_after_fee() public {
        vm.startPrank(king);
        vault.deposit(10 ether);
        vault.mint(5_000e18);
        vm.warp(block.timestamp + 30 days);
        vault.close();
        vm.stopPrank();
        assertEq(vault.coll(), 0);
        assertEq(vault.accruedDebt(), 0);
        assertEq(eusd.balanceOf(king), 0);
    }

    function test_stability_fee_accrues() public {
        vm.startPrank(king);
        vault.deposit(10 ether);
        vault.mint(5_000e18);
        vm.stopPrank();
        uint256 d0 = vault.accruedDebt();
        uint256 bal0 = eusd.balanceOf(king);
        vm.warp(block.timestamp + 365 days);
        vault.accrue();
        assertApproxEqRel(vault.accruedDebt() - d0, 250e18, 0.02e18);
        assertEq(eusd.balanceOf(king) - bal0, vault.accruedDebt() - d0);
    }

    function test_requires_zk() public {
        zkGate.setProven(king, false);
        vm.prank(king);
        vm.expectRevert(CrownAssetCdpVault.NotZkProven.selector);
        vault.deposit(1 ether);
    }

    function test_only_king() public {
        address rando = address(0xBEEF);
        zkGate.setProven(rando, true);
        vm.prank(rando);
        vm.expectRevert();
        vault.deposit(1 ether);
    }
}

contract CrownCbbtcCdpVaultTest is Test {
    address internal king = makeAddr("king");
    MockErc20Dec internal cbbtc;
    MockMorphoUsdOracle internal oracle;
    MockZkElepanGate internal zkGate;
    CrownElepanUsd internal eusd;
    HarnessAssetCdp internal vault;

    uint256 constant LR = 1.3e18;
    uint256 constant FLOOR = 1.35e18;
    uint256 constant FEE_BPS = 500;
    // $65000 cbBTC → morpho = 65000e6 * 1e36 / 1e8 = 6.5e29
    uint256 constant PX = 65_000e6 * 1e36 / 1e8;

    function setUp() public {
        cbbtc = new MockErc20Dec(8);
        oracle = new MockMorphoUsdOracle(PX);
        zkGate = new MockZkElepanGate();
        zkGate.setProven(king, true);
        eusd = new CrownElepanUsd(king);
        vault = new HarnessAssetCdp(address(cbbtc), address(eusd), address(oracle), address(zkGate), king, LR, FLOOR, FEE_BPS);
        vm.prank(king);
        eusd.setMinter(address(vault), true);
        cbbtc.mint(king, 100e8);
        vm.prank(king);
        cbbtc.approve(address(vault), type(uint256).max);
    }

    function test_wrapper_binds_cbbtc() public {
        CrownCbbtcCdpVault v = new CrownCbbtcCdpVault(
            address(eusd), address(oracle), address(zkGate), king, king, LR, FLOOR, FEE_BPS
        );
        assertEq(address(v.collateral()), v.CBTC());
        assertEq(v.CBTC(), 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf);
    }

    function test_deposit_mint_hf() public {
        vm.startPrank(king);
        vault.deposit(1e8); // 1 cbBTC ≈ $65k
        vault.mint(30_000e18); // HF ≈ 2.17
        vm.stopPrank();
        assertEq(vault.coll(), 1e8);
        assertGe(vault.healthFactor(), FLOOR);
    }

    function test_partial_withdraw_keeps_hf_above_floor() public {
        vm.startPrank(king);
        vault.deposit(2e8);
        vault.mint(60_000e18);
        vault.withdraw(0.5e8);
        vm.stopPrank();
        assertEq(vault.coll(), 1.5e8);
        assertGe(vault.healthFactor(), FLOOR);
    }

    function test_partial_withdraw_reverts_below_floor() public {
        vm.startPrank(king);
        vault.deposit(1e8);
        vault.mint(45_000e18); // HF ≈ 1.44
        vm.expectRevert(CrownAssetCdpVault.UnsafeHf.selector);
        vault.withdraw(0.2e8); // would breach floor
        vm.stopPrank();
    }

    function test_full_repay_unlocks_all() public {
        vm.startPrank(king);
        vault.deposit(1e8);
        vault.mint(20_000e18);
        vault.repay(20_000e18);
        vault.withdraw(1e8);
        vm.stopPrank();
        assertEq(vault.coll(), 0);
    }

    function test_close_after_fee() public {
        vm.startPrank(king);
        vault.deposit(1e8);
        vault.mint(20_000e18);
        vm.warp(block.timestamp + 30 days);
        vault.close();
        vm.stopPrank();
        assertEq(vault.coll(), 0);
        assertEq(eusd.balanceOf(king), 0);
    }

    function test_requires_zk() public {
        zkGate.setProven(king, false);
        vm.prank(king);
        vm.expectRevert(CrownAssetCdpVault.NotZkProven.selector);
        vault.deposit(1);
    }
}
