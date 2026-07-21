// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownZkAdvance} from "../src/CrownZkAdvance.sol";

contract MockErc20A {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    function mint(address to, uint256 amt) external { balanceOf[to] += amt; }
    function approve(address sp, uint256 amt) external returns (bool) { allowance[msg.sender][sp] = amt; return true; }
    function transfer(address to, uint256 amt) external returns (bool) {
        balanceOf[msg.sender] -= amt; balanceOf[to] += amt; return true;
    }
    function transferFrom(address f, address t, uint256 amt) external returns (bool) {
        uint256 a = allowance[f][msg.sender];
        if (a != type(uint256).max) allowance[f][msg.sender] = a - amt;
        balanceOf[f] -= amt; balanceOf[t] += amt; return true;
    }
}

contract MockGateA {
    bool public ok = true;
    uint256 public thr = 700_000e6;
    function set(bool v) external { ok = v; }
    function isProven(address) external view returns (bool) { return ok; }
    function attestations(address) external view returns (uint256, uint256, bool) {
        return (thr, block.timestamp, ok);
    }
}

/// @notice Ordered path: counterparty advance(500k) against ZK — not King self-fund.
contract ZkAdvanceOrderedTest is Test {
    address king = address(0xA11CE);
    address cold = address(0xC01D);
    address buyer = address(0xB0A7);

    MockErc20A usdc;
    MockErc20A kusd;
    MockGateA gate;
    CrownZkAdvance adv;

    function setUp() public {
        usdc = new MockErc20A();
        kusd = new MockErc20A();
        gate = new MockGateA();
        adv = new CrownZkAdvance(address(usdc), address(kusd), address(gate), king, cold, king);

        // King stocks kUSD (from CDP mint inventory) — sword inventory
        kusd.mint(king, 700_000e6);
        vm.startPrank(king);
        kusd.approve(address(adv), 700_000e6);
        adv.stockKusd(700_000e6);
        vm.stopPrank();
    }

    function test_ordered_advance_500k_zk_required() public {
        uint256 amt = 500_000e6;
        // Counterparty brings USDC — ZK layer purpose
        usdc.mint(buyer, amt);

        vm.startPrank(buyer);
        usdc.approve(address(adv), amt);
        adv.advance(amt);
        vm.stopPrank();

        assertEq(usdc.balanceOf(cold), amt, "USDC to Landing");
        assertEq(kusd.balanceOf(buyer), amt, "kUSD to buyer");
        assertEq(adv.raisedUsdc(), amt);
        console2.log("ORDERED_500K_OK", amt);
    }

    function test_reverts_if_king_not_proven() public {
        gate.set(false);
        usdc.mint(buyer, 500_000e6);
        vm.startPrank(buyer);
        usdc.approve(address(adv), 500_000e6);
        vm.expectRevert(CrownZkAdvance.KingNotProven.selector);
        adv.advance(500_000e6);
        vm.stopPrank();
    }
}
