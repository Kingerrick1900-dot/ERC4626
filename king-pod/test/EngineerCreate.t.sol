// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownKusd} from "../src/CrownKusd.sol";
import {CrownCdp} from "../src/CrownCdp.sol";
import {CrownSupplyMagnet} from "../src/CrownSupplyMagnet.sol";
import {CrownBribeBudget} from "../src/CrownBribeBudget.sol";

contract MockErc20 {
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory n, string memory s, uint8 d) {
        name = n;
        symbol = s;
        decimals = d;
    }

    function mint(address to, uint256 amt) external {
        totalSupply += amt;
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

    function transferFrom(address from, address to, uint256 amt) external returns (bool) {
        uint256 a = allowance[from][msg.sender];
        if (a != type(uint256).max) allowance[from][msg.sender] = a - amt;
        balanceOf[from] -= amt;
        balanceOf[to] += amt;
        return true;
    }
}

contract EngineerCreateTest is Test {
    address king = address(0xA11CE);
    MockErc20 rss;
    MockErc20 usdc;
    CrownKusd kusd;
    CrownCdp cdp;
    CrownSupplyMagnet book;
    CrownBribeBudget bribe;

    function setUp() public {
        rss = new MockErc20("RSS", "RSS", 18);
        usdc = new MockErc20("USDC", "USDC", 6);
        kusd = new CrownKusd(king);
        cdp = new CrownCdp(address(rss), address(kusd), king, king);
        vm.prank(king);
        kusd.setMinter(address(cdp));
        book = new CrownSupplyMagnet(address(usdc), address(rss), king, king);
        bribe = new CrownBribeBudget(address(rss), king, king);

        rss.mint(king, 10_000_000 ether);
        usdc.mint(address(0xBEEF), 1_000_000e6);
    }

    function test_cdp_mints_at_fixed_one() public {
        vm.startPrank(king);
        rss.approve(address(cdp), 1_000_000 ether);
        // 1M RSS @ $1 * 70% = 700_000e6 kUSD
        cdp.open(1_000_000 ether, 700_000e6);
        vm.stopPrank();
        assertEq(kusd.balanceOf(king), 700_000e6);
        assertEq(cdp.maxMint(king), 0);
    }

    function test_book_rebate_then_king_borrow() public {
        vm.startPrank(king);
        book.arm(0.02 ether, 700000000000000000); // 0.02 RSS per $1
        rss.approve(address(book), 2_100_000 ether);
        book.stockRebate(100_000 ether);
        book.postColl(2_000_000 ether);
        vm.stopPrank();

        vm.startPrank(address(0xBEEF));
        usdc.approve(address(book), 500_000e6);
        book.supply(500_000e6);
        // rebate = 500_000 * 0.02e18 / 1e6 = 10_000e18
        assertEq(rss.balanceOf(address(0xBEEF)), 10_000 ether);
        vm.stopPrank();

        vm.prank(king);
        book.borrow(350_000e6); // under 70% of 2M = 1.4M cap; liquidity 500k
        assertEq(usdc.balanceOf(king), 350_000e6);
    }

    function test_bribe_direct_rebate() public {
        vm.startPrank(king);
        rss.approve(address(bribe), 50_000 ether);
        bribe.stock(50_000 ether);
        address lp = address(0x1234);
        bribe.directRebate(lp, 10_000 ether);
        vm.stopPrank();
        assertEq(rss.balanceOf(lp), 10_000 ether);
        assertEq(bribe.budgetRss(), 40_000 ether);
    }
}
