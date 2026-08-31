// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownBoundLandingCollateral} from "../src/prime/CrownBoundLandingCollateral.sol";
import {CrownPrimeCredit} from "../src/prime/CrownPrimeCredit.sol";
import {CrownLitePsm} from "../src/prime/CrownLitePsm.sol";
import {CrownPrime7683Fill} from "../src/prime/CrownPrime7683Fill.sol";
import {USDCBorrowRouter} from "../src/prime/USDCBorrowRouter.sol";
import {SelfRepayingTreasury} from "../src/prime/SelfRepayingTreasury.sol";

contract MockERC20P {
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory n, string memory s, uint8 d) {
        name = n;
        symbol = s;
        decimals = d;
    }

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
    }

    function approve(address sp, uint256 amt) external returns (bool) {
        allowance[msg.sender][sp] = amt;
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

/// @notice Prime brokerage stack: lock float → solver/LitePSM USDC idle → borrow → self-repay.
contract PrimeBrokerageTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;

    MockERC20P eusd;
    MockERC20P gusd;
    MockERC20P usdc;

    CrownBoundLandingCollateral coll;
    CrownPrimeCredit credit;
    CrownLitePsm psm;
    CrownPrime7683Fill fill7683;
    USDCBorrowRouter router;
    SelfRepayingTreasury treasury;

    address solver = address(0xB0B);

    function setUp() public {
        eusd = new MockERC20P("eUSD", "eUSD", 18);
        gusd = new MockERC20P("gUSD", "gUSD", 18);
        usdc = new MockERC20P("USDC", "USDC", 6);

        coll = new CrownBoundLandingCollateral(address(eusd), address(gusd), HOT, HOT);
        credit = new CrownPrimeCredit(address(usdc), address(coll), HOT, LANDING, HOT);
        psm = new CrownLitePsm(address(eusd), address(usdc), HOT);
        treasury = new SelfRepayingTreasury(address(usdc), HOT, HOT);
        fill7683 = new CrownPrime7683Fill(address(eusd), address(usdc), HOT);
        router = new USDCBorrowRouter(address(coll), address(credit), address(usdc), HOT, HOT);

        vm.startPrank(HOT);
        coll.setDebtOperator(address(credit), true);
        coll.setLltv(30e16); // 30%
        credit.setOperator(address(router), true);
        credit.setOperator(address(psm), true);
        psm.setCredit(address(credit), true);
        treasury.setCredit(address(credit));
        fill7683.setConfig(address(psm), address(credit), address(treasury));
        router.setTargets(address(psm), LANDING);
        router.setArmed(true);
        vm.stopPrank();

        // King float
        eusd.mint(HOT, 100_000_000e18); // $100M float
        gusd.mint(HOT, 50_000_000e18);
        // Sell-side eUSD buffer for LitePSM + 7683
        eusd.mint(HOT, 10_000_000e18);
        usdc.mint(solver, 5_000_000e6);
    }

    function test_lock_float_no_liquidate() public {
        vm.startPrank(HOT);
        eusd.approve(address(coll), 22_000_000e18);
        coll.lockEusd(22_000_000e18);
        vm.stopPrank();

        // $22M coll @ 30% LLTV = $6.6M capacity
        assertEq(coll.collUsd6View(), 22_000_000e6);
        assertEq(coll.maxDebtUsd6(), 6_600_000e6);
        assertEq(coll.borrowCapacityUsd6(), 6_600_000e6);
        assertTrue(coll.nonLiquidatable());

        vm.expectRevert(CrownBoundLandingCollateral.NoLiq.selector);
        coll.liquidate(HOT, 1);
    }

    function test_capacity_without_idle_cannot_draw() public {
        vm.startPrank(HOT);
        eusd.approve(address(coll), 22_000_000e18);
        coll.lockEusd(22_000_000e18);
        vm.expectRevert(CrownPrimeCredit.IdleMiss.selector);
        router.draw(1_000_000e6, LANDING);
        vm.stopPrank();
    }

    function test_litePsm_sellGem_feeds_credit_then_draw() public {
        vm.startPrank(HOT);
        eusd.approve(address(coll), 22_000_000e18);
        coll.lockEusd(22_000_000e18);
        // Seed LitePSM eUSD sell buffer
        eusd.approve(address(psm), 2_000_000e18);
        psm.seedEusd(2_000_000e18);
        vm.stopPrank();

        // Solver / user brings USDC → eUSD; auto-feeds credit
        vm.startPrank(solver);
        usdc.approve(address(psm), 1_500_000e6);
        uint256 eOut = psm.sellGem(1_500_000e6, solver);
        vm.stopPrank();

        assertEq(eOut, 1_500_000e18);
        assertEq(credit.freeUsdc(), 1_500_000e6);
        assertEq(psm.usdcReserve(), 0); // fed to credit

        vm.prank(HOT);
        router.draw(1_500_000e6, LANDING);
        assertEq(usdc.balanceOf(LANDING), 1_500_000e6);
        assertEq(credit.debtOf(HOT), 1_500_000e6);
        assertEq(coll.reservedDebtUsd6(), 1_500_000e6);
    }

    function test_7683_solver_fill_creates_idle_and_fee_repays() public {
        vm.startPrank(HOT);
        eusd.approve(address(coll), 22_000_000e18);
        coll.lockEusd(22_000_000e18);
        eusd.approve(address(fill7683), 1_000_000e18);
        fill7683.seedFillBuffer(1_000_000e18);

        // Open order: 1M eUSD out, max 990k USDC in (1% discount)
        bytes32 oid = fill7683.openOrder(HOT, 1_000_000e18, 990_000e6, uint32(block.timestamp + 1 days));
        vm.stopPrank();

        vm.startPrank(solver);
        usdc.approve(address(fill7683), 990_000e6);
        fill7683.fill(oid, 990_000e6);
        vm.stopPrank();

        // protocolFeeBps = 10 → 0.1% of 990k = 990 USDC to treasury; rest to credit
        uint256 fee = (990_000e6 * 10) / 10_000;
        assertEq(usdc.balanceOf(address(treasury)), fee);
        assertEq(credit.freeUsdc(), 990_000e6 - fee);

        vm.prank(HOT);
        router.draw(500_000e6, LANDING);
        assertEq(credit.debtOf(HOT), 500_000e6);

        // Fee from fill already sits in treasury; sweep adds 100k → both repay
        uint256 feeBal = usdc.balanceOf(address(treasury));
        usdc.mint(address(this), 100_000e6);
        usdc.approve(address(treasury), 100_000e6);
        treasury.sweep(100_000e6);
        assertEq(credit.debtOf(HOT), 500_000e6 - 100_000e6 - feeBal);
        assertEq(treasury.totalRepaid(), 100_000e6 + feeBal);
    }

    function test_full_prime_loop_draw_to_psm_and_repay() public {
        vm.startPrank(HOT);
        eusd.approve(address(coll), 22_000_000e18);
        coll.lockEusd(22_000_000e18);
        eusd.approve(address(psm), 3_000_000e18);
        psm.seedEusd(3_000_000e18);
        vm.stopPrank();

        vm.startPrank(solver);
        usdc.approve(address(psm), 2_000_000e6);
        psm.sellGem(2_000_000e6, solver);
        vm.stopPrank();

        // 30% of $22M = $6.6M capacity; idle = $2M
        assertEq(router.maxDraw(), 2_000_000e6);

        vm.prank(HOT);
        router.drawToPsm(2_000_000e6);
        // PSM received USDC (not auto-fed — draw lands on psm balance)
        assertEq(usdc.balanceOf(address(psm)), 2_000_000e6);
        assertEq(credit.debtOf(HOT), 2_000_000e6);

        // Tax sweep clears debt
        usdc.mint(HOT, 2_000_000e6);
        vm.startPrank(HOT);
        usdc.approve(address(treasury), 2_000_000e6);
        treasury.sweep(2_000_000e6);
        vm.stopPrank();

        assertEq(credit.debtOf(HOT), 0);
        assertEq(coll.reservedDebtUsd6(), 0);
        // King can unlock float again
        vm.prank(HOT);
        coll.unlockEusd(22_000_000e18, HOT);
        assertEq(coll.eusdLocked(), 0);
    }
}
