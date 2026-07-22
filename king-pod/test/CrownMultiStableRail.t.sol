// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownMultiStableRail} from "../src/CrownMultiStableRail.sol";

contract MockTok {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint8 public immutable decimals;
    constructor(uint8 d) { decimals = d; }
    function mint(address t, uint256 a) external { balanceOf[t] += a; }
    function approve(address s, uint256 a) external returns (bool) { allowance[msg.sender][s] = a; return true; }
    function transfer(address t, uint256 a) external returns (bool) {
        balanceOf[msg.sender] -= a; balanceOf[t] += a; return true;
    }
    function transferFrom(address f, address t, uint256 a) external returns (bool) {
        uint256 x = allowance[f][msg.sender];
        if (x != type(uint256).max) allowance[f][msg.sender] = x - a;
        balanceOf[f] -= a; balanceOf[t] += a; return true;
    }
}

contract MockMsg {
    function depositForBurn(uint256 amount, uint32, bytes32, address burnToken, bytes32, uint256, uint32)
        external
        returns (uint64)
    {
        MockTok(burnToken).transferFrom(msg.sender, address(this), amount);
        return 1;
    }
}

contract CrownMultiStableRailTest is Test {
    MockTok dai;
    MockTok usdt;
    MockTok usdc;
    MockTok weth;
    MockTok rss;
    CrownMultiStableRail rail;
    address land = address(0x1A11D);
    address desk = address(0xDE5B);

    function setUp() public {
        dai = new MockTok(6);
        usdt = new MockTok(6);
        usdc = new MockTok(6);
        weth = new MockTok(18);
        rss = new MockTok(18);
        rail = new CrownMultiStableRail(
            address(dai), address(usdt), address(usdc), address(weth), address(rss),
            address(new MockMsg()), land, address(this)
        );
        rss.mint(address(this), 2_000_000 ether);
        rss.approve(address(rail), type(uint256).max);
        rail.stockRss(1_400_000 ether);
        dai.mint(desk, 700_000e6);
        usdt.mint(desk, 700_000e6);
        weth.mint(desk, 300 ether);
        vm.deal(desk, 300 ether);
        vm.deal(land, 0);
    }

    function test_fill_dai_500k_to_landing() public {
        vm.startPrank(desk);
        dai.approve(address(rail), 500_000e6);
        rail.fillStable(address(dai), 500_000e6, 500_000 ether, 1);
        vm.stopPrank();
        assertEq(dai.balanceOf(land), 500_000e6);
        assertEq(rss.balanceOf(desk), 500_000 ether);
    }

    function test_fill_usdt_700k() public {
        vm.startPrank(desk);
        usdt.approve(address(rail), 700_000e6);
        rail.fillStable(address(usdt), 700_000e6, 700_000 ether, 1);
        vm.stopPrank();
        assertEq(usdt.balanceOf(land), 700_000e6);
    }

    function test_fill_eth_native() public {
        vm.prank(desk);
        rail.fillEth{value: 200 ether}(500_000 ether);
        assertEq(land.balance, 200 ether);
        assertEq(rss.balanceOf(desk), 500_000 ether);
    }
}
