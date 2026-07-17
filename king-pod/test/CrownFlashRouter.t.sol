// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownFlashRouter, ICrownFlashBorrower} from "../src/CrownFlashRouter.sol";
import {IERC20} from "../src/lib/Core.sol";

contract MockERC20 {
    string public name = "USDC";
    string public symbol = "USDC";
    uint8 public decimals = 6;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
        totalSupply += amt;
    }

    function approve(address sp, uint256 amt) external returns (bool) {
        allowance[msg.sender][sp] = amt;
        return true;
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        require(balanceOf[msg.sender] >= amt, "BAL");
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        return true;
    }

    function transferFrom(address from, address to, uint256 amt) external returns (bool) {
        uint256 a = allowance[from][msg.sender];
        require(a >= amt, "ALLOW");
        if (a != type(uint256).max) allowance[from][msg.sender] = a - amt;
        require(balanceOf[from] >= amt, "BAL");
        balanceOf[from] -= amt;
        balanceOf[to] += amt;
        return true;
    }
}

contract MockMorpho {
    MockERC20 public usdc;
    constructor(MockERC20 u) { usdc = u; }

    function flashLoan(address token, uint256 assets, bytes calldata data) external {
        token;
        data;
        usdc.transfer(msg.sender, assets);
        IMorphoCB(msg.sender).onMorphoFlashLoan(assets, bytes(""));
        usdc.transferFrom(msg.sender, address(this), assets);
    }
}

interface IMorphoCB {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

contract TestBorrower is ICrownFlashBorrower {
    CrownFlashRouter public router;
    MockERC20 public usdc;
    bool public failApprove;

    constructor(CrownFlashRouter r, MockERC20 u) {
        router = r;
        usdc = u;
    }

    function go(uint256 assets) external {
        router.flashLoan(assets, bytes("hi"));
    }

    function onCrownFlash(uint256 assets, uint256 fee, bytes calldata) external override {
        // Simulate profitable use: we already have fee buffer minted to this contract
        usdc.approve(address(router), assets + fee);
    }
}

contract CrownFlashRouterTest is Test {
    MockERC20 usdc;
    MockMorpho morpho;
    CrownFlashRouter router;
    TestBorrower borrower;
    address king = address(0xA11CE);

    function setUp() public {
        usdc = new MockERC20();
        morpho = new MockMorpho(usdc);
        router = new CrownFlashRouter(address(morpho), address(usdc), king, 5, king);
        borrower = new TestBorrower(router, usdc);
        // Morpho liquidity
        usdc.mint(address(morpho), 1_000_000e6);
        // Borrower holds fee dust
        usdc.mint(address(borrower), 1_000e6);
    }

    function testFlashPaysFeeToTreasury() public {
        uint256 assets = 100_000e6;
        uint256 fee = router.quoteFee(assets); // 50e6 at 5 bps
        assertEq(fee, 50e6);
        borrower.go(assets);
        assertEq(usdc.balanceOf(king), fee);
        assertEq(usdc.balanceOf(address(morpho)), 1_000_000e6);
    }
}
