// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownOtcEthRail} from "../src/CrownOtcEthRail.sol";

contract MockErc20R {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint8 public immutable decimals;

    constructor(uint8 d) {
        decimals = d;
    }

    function mint(address to, uint256 amt) external {
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

contract MockMessenger {
    uint64 public nonce;
    address public lastToken;
    uint256 public lastAmt;
    bytes32 public lastMint;

    function depositForBurn(
        uint256 amount,
        uint32,
        bytes32 mintRecipient,
        address burnToken,
        bytes32,
        uint256,
        uint32
    ) external returns (uint64) {
        // pull burn token
        MockErc20R(burnToken).transferFrom(msg.sender, address(this), amount);
        lastAmt = amount;
        lastToken = burnToken;
        lastMint = mintRecipient;
        nonce += 1;
        return nonce;
    }
}

contract CrownOtcEthRailTest is Test {
    MockErc20R usdc;
    MockErc20R rss;
    MockErc20R kusd;
    MockMessenger messenger;
    CrownOtcEthRail rail;
    address land = address(0x1A11D);
    address desk = address(0xDE5B);

    function setUp() public {
        usdc = new MockErc20R(6);
        rss = new MockErc20R(18);
        kusd = new MockErc20R(6);
        messenger = new MockMessenger();
        rail = new CrownOtcEthRail(
            address(usdc), address(rss), address(kusd), address(messenger), land, address(this)
        );
        rss.mint(address(this), 1_000_000 ether);
        rss.approve(address(rail), 700_000 ether);
        rail.stockRss(700_000 ether);
        usdc.mint(desk, 700_000e6);
    }

    function test_fill_eth_500k_burns_and_pays_rss() public {
        vm.startPrank(desk);
        usdc.approve(address(rail), 500_000e6);
        rail.fill(500_000e6, 500_000 ether, 0, 2);
        vm.stopPrank();
        assertEq(messenger.lastAmt(), 500_000e6);
        assertEq(uint256(messenger.lastMint()), uint256(uint160(land)));
        assertEq(rss.balanceOf(desk), 500_000 ether);
        assertEq(rail.bridgedUsdc(), 500_000e6);
    }

    function test_fill_below_500k_reverts() public {
        vm.startPrank(desk);
        usdc.approve(address(rail), 100_000e6);
        vm.expectRevert(CrownOtcEthRail.BadAmt.selector);
        rail.fill(100_000e6, 100_000 ether, 0, 2);
        vm.stopPrank();
    }

    function test_fill_base_hits_landing() public {
        vm.startPrank(desk);
        usdc.approve(address(rail), 500_000e6);
        rail.fill(500_000e6, 500_000 ether, 0, 1);
        vm.stopPrank();
        assertEq(usdc.balanceOf(land), 500_000e6);
    }
}
