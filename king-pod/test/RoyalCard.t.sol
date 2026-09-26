// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RoyalCard} from "../src/royal/RoyalCard.sol";
import {CrownPayAdapter} from "../src/CrownPayAdapter.sol";

contract MockEusd {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    function mint(address to, uint256 a) external { balanceOf[to] += a; }
    function approve(address s, uint256 a) external returns (bool) { allowance[msg.sender][s] = a; return true; }
    function transfer(address to, uint256 a) external returns (bool) {
        balanceOf[msg.sender] -= a; balanceOf[to] += a; return true;
    }
    function transferFrom(address f, address t, uint256 a) external returns (bool) {
        uint256 al = allowance[f][msg.sender];
        require(al >= a, "A");
        if (al != type(uint256).max) allowance[f][msg.sender] = al - a;
        balanceOf[f] -= a; balanceOf[t] += a; return true;
    }
}

contract RoyalCardTest is Test {
    MockEusd eusd;
    CrownPayAdapter pay;
    RoyalCard card;
    address king;
    address holder;
    address merc;
    bytes32 cardId = keccak256("c1");

    function setUp() public {
        king = makeAddr("king");
        holder = makeAddr("holder");
        merc = makeAddr("merc");
        eusd = new MockEusd();
        pay = new CrownPayAdapter(address(eusd), king);
        card = new RoyalCard(address(eusd), king);
        vm.startPrank(king);
        pay.setMerchant(merc, true);
        card.setModules(address(pay), address(0));
        card.issue(cardId, holder, keccak256("pk"), 100 ether);
        vm.stopPrank();
        eusd.mint(holder, 50 ether);
    }

    function test_spend_listed_merchant() public {
        vm.startPrank(holder);
        eusd.approve(address(card), 10 ether);
        card.spend(cardId, merc, 10 ether, keccak256("r"));
        vm.stopPrank();
        assertEq(eusd.balanceOf(merc), 10 ether);
    }

    function test_spend_unlisted_reverts() public {
        address bad = makeAddr("bad");
        vm.startPrank(holder);
        eusd.approve(address(card), 1 ether);
        vm.expectRevert(RoyalCard.BadMerchant.selector);
        card.spend(cardId, bad, 1 ether, bytes32(0));
        vm.stopPrank();
    }
}
