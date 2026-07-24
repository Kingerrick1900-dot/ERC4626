// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownYelepanStream} from "../src/CrownYelepanStream.sol";

contract MockERC20 {
    string public name = "Elepan";
    string public symbol = "ELE";
    uint8 public decimals = 8;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
    }

    function approve(address spender, uint256 amt) external returns (bool) {
        allowance[msg.sender][spender] = amt;
        return true;
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        require(balanceOf[msg.sender] >= amt, "BAL");
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        return true;
    }

    function transferFrom(address from, address to, uint256 amt) external returns (bool) {
        require(balanceOf[from] >= amt, "BAL");
        require(allowance[from][msg.sender] >= amt, "ALLOW");
        allowance[from][msg.sender] -= amt;
        balanceOf[from] -= amt;
        balanceOf[to] += amt;
        return true;
    }
}

contract MockVault {
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;

    function mint(address to, uint256 shares) external {
        balanceOf[to] += shares;
        totalSupply += shares;
    }

    function burn(address from, uint256 shares) external {
        balanceOf[from] -= shares;
        totalSupply -= shares;
    }
}

contract CrownYelepanStreamTest is Test {
    MockERC20 ele;
    MockVault vault;
    CrownYelepanStream stream;
    address owner = makeAddr("owner");
    address landing = makeAddr("landing");
    address externalLp = makeAddr("externalLp");

    function setUp() public {
        ele = new MockERC20();
        vault = new MockVault();
        vm.prank(owner);
        stream = new CrownYelepanStream(address(ele), address(vault), owner);

        vm.startPrank(owner);
        stream.setBlacklist(landing, true);
        ele.mint(owner, 10_000_000e8);
        ele.approve(address(stream), type(uint256).max);
        vm.stopPrank();
    }

    function test_noAccrualWhileOnlyTreasuryHoldsShares() public {
        vault.mint(landing, 1_000e18);
        vm.prank(owner);
        stream.notifyRewardAmount(4_000_000e8, 28 days);

        assertEq(stream.eligibleSupply(), 0);
        vm.warp(block.timestamp + 7 days);
        assertEq(stream.earned(landing), 0);
        assertEq(stream.rewardPerShare(), 0);
        // budget still sitting — waiting for external depositors
        assertEq(ele.balanceOf(address(stream)), 4_000_000e8);
    }

    function test_externalDepositorEarnsAndTreasuryDoesNot() public {
        vault.mint(landing, 9_000e18);
        vault.mint(externalLp, 1_000e18);

        vm.prank(owner);
        stream.notifyRewardAmount(2_800_000e8, 28 days); // 100_000e8 / day

        assertEq(stream.eligibleSupply(), 1_000e18);

        vm.warp(block.timestamp + 1 days);
        uint256 due = stream.earned(externalLp);
        // ~100k Elepan/day to the only eligible shares
        assertApproxEqRel(due, 100_000e8, 0.01e18);
        assertEq(stream.earned(landing), 0);

        vm.prank(externalLp);
        stream.claim();
        assertApproxEqRel(ele.balanceOf(externalLp), 100_000e8, 0.01e18);
    }
}
