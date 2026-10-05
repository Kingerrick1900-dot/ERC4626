// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownSpoilsOfWar} from "../src/CrownSpoilsOfWar.sol";
import {CrownColdBuffer} from "../src/CrownColdBuffer.sol";

contract MockUsdcS {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

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

contract SpoilsOfWarTest is Test {
    MockUsdcS usdc;
    CrownColdBuffer cold;
    CrownSpoilsOfWar spoils;
    address king;
    address hot;
    address ocean;
    address raider;

    function setUp() public {
        king = makeAddr("king");
        hot = makeAddr("hot");
        ocean = makeAddr("ocean");
        raider = makeAddr("raider");
        usdc = new MockUsdcS();
        cold = new CrownColdBuffer(address(usdc), king, address(0));
        spoils = new CrownSpoilsOfWar(address(usdc), address(cold), hot, ocean, king);
    }

    function test_spoil_split_30_50_20() public {
        usdc.mint(raider, 1_000_000e6);
        vm.prank(raider);
        usdc.approve(address(spoils), type(uint256).max);
        vm.prank(raider);
        spoils.takeSpoil(1_000_000e6, bytes32("ROUTE_B"));

        assertEq(usdc.balanceOf(address(cold)), 300_000e6);
        assertEq(usdc.balanceOf(ocean), 500_000e6);
        assertEq(usdc.balanceOf(hot), 200_000e6);
        (uint256 t, uint256 c, uint256 o, uint256 h,,) = spoils.book();
        assertEq(t, 1_000_000e6);
        assertEq(c, 300_000e6);
        assertEq(o, 500_000e6);
        assertEq(h, 200_000e6);
    }

    function test_cold_floor() public {
        vm.prank(king);
        vm.expectRevert(CrownSpoilsOfWar.BadBps.selector);
        spoils.setBps(2999, 5000);
    }
}
