// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownCircuitBreaker} from "../src/CrownCircuitBreaker.sol";
import {ColdBufferLaw} from "../src/ColdBufferLaw.sol";
import {MintGate} from "../src/MintGate.sol";
import {CrownColdBuffer} from "../src/CrownColdBuffer.sol";
import {IERC20} from "../src/lib/Core.sol";

contract MockUsdcA {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint8 public decimals = 6;

    function mint(address to, uint256 a) external {
        balanceOf[to] += a;
    }

    function approve(address s, uint256 a) external returns (bool) {
        allowance[msg.sender][s] = a;
        return true;
    }

    function transfer(address to, uint256 a) external returns (bool) {
        balanceOf[msg.sender] -= a;
        balanceOf[to] += a;
        return true;
    }

    function transferFrom(address f, address to, uint256 a) external returns (bool) {
        uint256 al = allowance[f][msg.sender];
        if (al != type(uint256).max) allowance[f][msg.sender] = al - a;
        balanceOf[f] -= a;
        balanceOf[to] += a;
        return true;
    }
}

contract MockAMO {
    bool public paused;

    function emergencyPause() external {
        paused = true;
    }
}

contract MockSafeRouter {
    uint256 public lastAmt;

    function routeToSafeVenue(uint256 amount) external {
        lastAmt = amount;
    }
}

contract RewardAMO is ColdBufferLaw {
    constructor(address cold, address usdc) ColdBufferLaw(cold, usdc) {}

    function takeFees(uint256 amt) external returns (uint256 left) {
        // fees already on this contract
        return _routeRewards(amt);
    }
}

contract Amo6ArmorTest is Test {
    address king;
    MockUsdcA usdc;
    CrownColdBuffer cold;
    CrownCircuitBreaker brk;
    MintGate gate;
    MockAMO amo;
    MockSafeRouter safe;
    RewardAMO rewardAmo;

    function setUp() public {
        king = makeAddr("king");
        usdc = new MockUsdcA();
        cold = new CrownColdBuffer(address(usdc), king, address(0));
        safe = new MockSafeRouter();
        brk = new CrownCircuitBreaker(king, address(safe), 1_000_000e18);
        gate = new MintGate(king);
        amo = new MockAMO();
        rewardAmo = new RewardAMO(address(cold), address(usdc));

        vm.prank(king);
        brk.registerAMO(address(amo));
    }

    function test_mintGate_ships_locked() public view {
        assertEq(gate.unlocked(), 0);
        assertFalse(gate.canMint());
    }

    function test_mintGate_king_unlock_and_lock() public {
        vm.prank(king);
        gate.unlockTranche(1e18);
        assertTrue(gate.canMint());
        assertEq(gate.unlocked(), 1e18);
        vm.prank(king);
        gate.lockAll();
        assertFalse(gate.canMint());
        assertEq(gate.unlocked(), 0);
    }

    function test_mintGate_non_king_reverts() public {
        vm.expectRevert(MintGate.KingOnly.selector);
        gate.unlockTranche(1);
    }

    function test_breaker_trips_on_eusd_floor() public {
        assertTrue(brk.armed());
        assertFalse(brk.tripped());
        brk.checkAndTrip(0.97e18, 1_000_000e18);
        assertTrue(brk.tripped());
        assertTrue(amo.paused());
    }

    function test_breaker_trips_on_yrss_drop() public {
        // baseline 1e24; drop >5% → 0.94e24
        brk.checkAndTrip(1e18, 940_000e18);
        assertTrue(brk.tripped());
        assertTrue(amo.paused());
    }

    function test_breaker_no_trip_when_healthy() public {
        brk.checkAndTrip(1e18, 1_000_000e18);
        assertFalse(brk.tripped());
        assertFalse(amo.paused());
    }

    function test_breaker_route_after_trip() public {
        brk.checkAndTrip(0.97e18, 1_000_000e18);
        vm.prank(king);
        brk.routeToSafe(100e6);
        assertEq(safe.lastAmt(), 100e6);
    }

    function test_cold_law_30_70() public {
        usdc.mint(address(rewardAmo), 1_000_000e6);
        uint256 left = rewardAmo.takeFees(1_000_000e6);
        assertEq(left, 700_000e6);
        assertEq(usdc.balanceOf(address(cold)), 300_000e6);
        assertEq(usdc.balanceOf(address(rewardAmo)), 700_000e6);
        assertEq(rewardAmo.minBufferBps(), 3000);
    }

    function test_cold_buffer_default_bps() public view {
        assertEq(cold.minBufferBps(), 3000);
    }
}
