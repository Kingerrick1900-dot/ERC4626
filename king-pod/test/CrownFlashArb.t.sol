// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownFlashRouter, ICrownFlashBorrower} from "../src/CrownFlashRouter.sol";
import {CrownFlashArb} from "../src/CrownFlashArb.sol";
import {IERC20} from "../src/lib/Core.sol";

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
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
    constructor(MockERC20 u) {
        usdc = u;
    }

    function flashLoan(address, uint256 assets, bytes calldata) external {
        usdc.transfer(msg.sender, assets);
        IMorphoCB(msg.sender).onMorphoFlashLoan(assets, bytes(""));
        usdc.transferFrom(msg.sender, address(this), assets);
    }
}

interface IMorphoCB {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

/// @dev Fake swap router: turns USDC into more USDC (profit) by minting on sell leg.
contract MockSwapRouter {
    MockERC20 public usdc;
    uint256 public bump;

    constructor(MockERC20 u, uint256 bump_) {
        usdc = u;
        bump = bump_;
    }

    // Ignored calldata — any call mints bump USDC to msg.sender once (sell)
    fallback() external payable {
        if (bump > 0) {
            usdc.mint(msg.sender, bump);
            bump = 0;
        }
    }
}

contract CrownFlashArbTest is Test {
    MockERC20 usdc;
    MockMorpho morpho;
    CrownFlashRouter router;
    CrownFlashArb arb;
    MockSwapRouter swap;
    address king = address(0xA11CE);
    address op = address(0xB0B);

    function setUp() public {
        usdc = new MockERC20();
        morpho = new MockMorpho(usdc);
        router = new CrownFlashRouter(address(morpho), address(usdc), king, 5, king);
        // bump covers 5 bps fee on 100k (=50) plus $25 profit
        swap = new MockSwapRouter(usdc, 75e6);
        arb = new CrownFlashArb(address(router), address(usdc), king, king, op);
        usdc.mint(address(morpho), 1_000_000e6);
    }

    function testFlashArbPaysKingFeeAndProfit() public {
        uint256 assets = 100_000e6;
        uint256 fee = router.quoteFee(assets); // 50e6
        vm.prank(op);
        arb.flashArbitrage(assets, address(swap), hex"01", address(swap), hex"02", 25e6);
        assertEq(usdc.balanceOf(king), fee + 25e6); // router fee + arb profit
        assertEq(usdc.balanceOf(address(morpho)), 1_000_000e6);
    }

    function testUnauthorizedReverts() public {
        vm.expectRevert(CrownFlashArb.NotAuthorized.selector);
        arb.flashArbitrage(1e6, address(swap), hex"01", address(swap), hex"02", 0);
    }
}
