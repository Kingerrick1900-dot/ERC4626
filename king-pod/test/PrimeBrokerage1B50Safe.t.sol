// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownBoundLandingCollateral} from "../src/prime/CrownBoundLandingCollateral.sol";
import {CrownPrimeCredit} from "../src/prime/CrownPrimeCredit.sol";
import {USDCBorrowRouter} from "../src/prime/USDCBorrowRouter.sol";
import {CrownPrimeSafeParams} from "../src/prime/CrownPrimeSafeParams.sol";

contract MockERC20Safe {
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

/// @notice 1B / 50% LLTV / paper $22M safe-draw suite — must pass 6/6.
contract PrimeBrokerage1B50SafeTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;

    MockERC20Safe eusd;
    MockERC20Safe usdc;
    CrownBoundLandingCollateral coll;
    CrownPrimeCredit credit;
    USDCBorrowRouter router;

    function setUp() public {
        eusd = new MockERC20Safe("eUSD", "eUSD", 18);
        usdc = new MockERC20Safe("USDC", "USDC", 6);

        coll = new CrownBoundLandingCollateral(address(eusd), address(0), HOT, HOT);
        credit = new CrownPrimeCredit(address(usdc), address(coll), HOT, LANDING, HOT);
        router = new USDCBorrowRouter(address(coll), address(credit), address(usdc), HOT, HOT);

        vm.startPrank(HOT);
        coll.setDebtOperator(address(credit), true);
        coll.setFloatUsd8(CrownPrimeSafeParams.PAPER_FLOAT_USD8);
        coll.setLltv(CrownPrimeSafeParams.LLTV_50);
        credit.setOperator(address(router), true);
        router.setTargets(address(0), LANDING);
        vm.stopPrank();

        // Full 1B mint locked as credit base at paper mark
        eusd.mint(HOT, CrownPrimeSafeParams.MINT_1B);
        vm.startPrank(HOT);
        eusd.approve(address(coll), CrownPrimeSafeParams.MINT_1B);
        coll.lockEusd(CrownPrimeSafeParams.MINT_1B);
        vm.stopPrank();
    }

    function test_paperPrice_22M() public view {
        assertEq(coll.collUsd6View(), CrownPrimeSafeParams.PAPER_USD6);
    }

    function test_kingDrawMax_50() public view {
        // 50% of $22M paper = $11M
        assertEq(coll.lltv(), 50e16);
        assertEq(coll.maxDebtUsd6(), CrownPrimeSafeParams.MAX_DEBT_USD6);
        assertEq(coll.borrowCapacityUsd6(), CrownPrimeSafeParams.MAX_DEBT_USD6);
    }

    function test_backing_281pct() public {
        // Simulate $9M USDC idle from sales sitting in credit
        usdc.mint(address(credit), 9_000_000e6);
        uint256 paper = coll.collUsd6View();
        uint256 idle = credit.freeUsdc();
        uint256 backing = paper + idle;
        uint256 debtMax = coll.maxDebtUsd6();
        // 31 / 11 ≈ 281%
        assertEq(backing, 31_000_000e6);
        assertEq(debtMax, 11_000_000e6);
        assertGe((backing * 100) / debtMax, 281);
    }

    function test_emergencyCap_2M() public {
        usdc.mint(address(this), 2_000_000e6);
        // Supply into credit so cash exists (sales landed)
        usdc.approve(address(credit), 2_000_000e6);
        credit.supply(2_000_000e6);

        assertFalse(router.armed());
        vm.prank(HOT);
        router.kingEmergencyDraw(2_000_000e6);
        assertEq(usdc.balanceOf(LANDING), 2_000_000e6);
        assertEq(router.emergencyDrawn(), 2_000_000e6);
        assertTrue(router.emergencyUsed());

        usdc.mint(address(this), 1);
        usdc.approve(address(credit), 1);
        credit.supply(1);
        vm.prank(HOT);
        vm.expectRevert(USDCBorrowRouter.EmergencyUsed.selector);
        router.kingEmergencyDraw(1);
    }

    function test_noDrawOver_11M() public {
        usdc.mint(address(this), 12_000_000e6);
        usdc.approve(address(credit), 12_000_000e6);
        credit.supply(12_000_000e6);

        vm.startPrank(HOT);
        router.setArmed(true);
        // Capacity == $11M hard ceiling at 50% paper; over-ask hits CapacityMiss first
        vm.expectRevert(USDCBorrowRouter.CapacityMiss.selector);
        router.draw(11_000_001e6, LANDING);
        router.draw(11_000_000e6, LANDING);
        vm.stopPrank();
        assertEq(credit.debtOf(HOT), 11_000_000e6);
        assertEq(coll.borrowCapacityUsd6(), 0);
    }

    function test_idleBeforeArm() public {
        // Capacity exists but no idle and not armed → cannot draw
        vm.startPrank(HOT);
        vm.expectRevert(USDCBorrowRouter.NotArmed.selector);
        router.draw(1e6, LANDING);
        router.setArmed(true);
        vm.expectRevert(USDCBorrowRouter.IdleMiss.selector);
        router.draw(1e6, LANDING);
        vm.stopPrank();
    }
}
