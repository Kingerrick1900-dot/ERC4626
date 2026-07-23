// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownOneDrop} from "../src/CrownOneDrop.sol";

contract MockErc20OD {
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;

    constructor(string memory n, string memory s, uint8 d) {
        name = n;
        symbol = s;
        decimals = d;
    }

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
        totalSupply += amt;
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

/// @dev Minimal CrownCdp stand-in: pull RSS, track coll/debt, mint kUSD to caller.
contract MockCdpOD {
    MockErc20OD public rss;
    MockErc20OD public kusd;
    mapping(address => uint256) public collOf;
    mapping(address => uint256) public debtOf;

    constructor(address rss_, address kusd_) {
        rss = MockErc20OD(rss_);
        kusd = MockErc20OD(kusd_);
    }

    function deposit(uint256 collAmt) external {
        rss.transferFrom(msg.sender, address(this), collAmt);
        collOf[msg.sender] += collAmt;
    }

    function mint(uint256 mintAmt) external {
        debtOf[msg.sender] += mintAmt;
        kusd.mint(msg.sender, mintAmt);
    }
}

contract MockAero {
    MockErc20OD public usdc;
    MockErc20OD public kusd;

    constructor(address usdc_, address kusd_) {
        usdc = MockErc20OD(usdc_);
        kusd = MockErc20OD(kusd_);
    }

    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256,
        Route[] calldata,
        address to,
        uint256
    ) external returns (uint256[] memory amounts) {
        kusd.transferFrom(msg.sender, address(this), amountIn);
        usdc.mint(to, amountIn); // 1:1 mock
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountIn;
    }
}

contract CrownOneDropTest is Test {
    MockErc20OD rss;
    MockErc20OD usdc;
    MockErc20OD kusd;
    MockCdpOD cdp;
    MockAero aero;
    CrownOneDrop drop;
    address king = address(0xA11CE);
    address land = address(0x1A11D);

    function setUp() public {
        rss = new MockErc20OD("RSS", "RSS", 18);
        usdc = new MockErc20OD("USDC", "USDC", 6);
        kusd = new MockErc20OD("kUSD", "kUSD", 6);
        cdp = new MockCdpOD(address(rss), address(kusd));
        aero = new MockAero(address(usdc), address(kusd));

        drop = new CrownOneDrop(
            address(0xB0B),
            address(aero),
            address(0xFAC),
            address(kusd),
            address(usdc),
            address(rss),
            address(cdp),
            land,
            address(0x0A0A),
            address(0x0B0B),
            770000000000000000
        );

        rss.mint(king, 2_000_000 ether);
    }

    function test_one_drop_mints_and_lands_usdc() public {
        vm.startPrank(king);
        rss.approve(address(drop), 1_000_000 ether);
        drop.execute(1_000_000 ether, 700_000e6, 0, 0);
        vm.stopPrank();
        assertEq(usdc.balanceOf(land), 700_000e6);
        assertEq(cdp.collOf(address(drop)), 1_000_000 ether);
        assertEq(cdp.debtOf(address(drop)), 700_000e6);
    }
}
