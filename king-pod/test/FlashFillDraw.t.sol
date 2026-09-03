// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownPrimeFlashFillDraw} from "../src/prime/CrownPrimeFlashFillDraw.sol";
import {CrownBoundLandingCollateral} from "../src/prime/CrownBoundLandingCollateral.sol";
import {CrownPrimeCredit} from "../src/prime/CrownPrimeCredit.sol";
import {CrownPrime7683Fill} from "../src/prime/CrownPrime7683Fill.sol";
import {SelfRepayingTreasury} from "../src/prime/SelfRepayingTreasury.sol";

contract MockUsdcF {
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

contract MockMorphoFlashF {
    MockUsdcF public usdc;

    constructor(address usdc_) {
        usdc = MockUsdcF(usdc_);
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external {
        require(token == address(usdc), "TOK");
        usdc.transfer(msg.sender, assets);
        IMorphoFlashLoanCallbackF(msg.sender).onMorphoFlashLoan(assets, data);
        require(usdc.transferFrom(msg.sender, address(this), assets), "REPAY");
    }
}

interface IMorphoFlashLoanCallbackF {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

contract MockEusdF {
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

contract FlashFillDrawTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;

    MockUsdcF usdc;
    MockEusdF eusd;
    MockMorphoFlashF morpho;
    CrownBoundLandingCollateral coll;
    CrownPrimeCredit credit;
    CrownPrime7683Fill fill7683;
    SelfRepayingTreasury treasury;
    CrownPrimeFlashFillDraw engine;

    function setUp() public {
        usdc = new MockUsdcF();
        eusd = new MockEusdF();
        morpho = new MockMorphoFlashF(address(usdc));
        usdc.mint(address(morpho), 20_000_000e6);

        coll = new CrownBoundLandingCollateral(address(eusd), address(0), HOT, HOT);
        credit = new CrownPrimeCredit(address(usdc), address(coll), HOT, LANDING, HOT);
        fill7683 = new CrownPrime7683Fill(address(eusd), address(usdc), HOT);
        treasury = new SelfRepayingTreasury(address(usdc), HOT, HOT);
        engine = new CrownPrimeFlashFillDraw(
            address(morpho), address(usdc), address(fill7683), address(credit), address(treasury), LANDING, HOT, HOT
        );

        vm.startPrank(HOT);
        fill7683.setConfig(address(0), address(credit), address(treasury));
        fill7683.setFees(1000, 0); // zero protocol fee — flash repay == credit supply
        coll.setDebtOperator(address(credit), true);
        coll.setFloatUsd8(2.2e6);
        coll.setLltv(50e16);
        credit.setOperator(address(engine), true);
        treasury.setCredit(address(credit));
        eusd.mint(HOT, 2_000_000_000e18);
        eusd.approve(address(fill7683), 5_000_000e18);
        fill7683.seedFillBuffer(5_000_000e18);
        eusd.approve(address(coll), 1_000_000_000e18);
        coll.lockEusd(1_000_000_000e18);
        vm.stopPrank();
    }

    function test_flash_fill_roundtrip_zero_idle() public {
        bytes32 oid = fill7683.openOrder(HOT, 5_000_000e18, 4_500_000e6, uint32(block.timestamp + 1 days));
        uint256 ask = 4_500_000e6;

        uint256 eBefore = eusd.balanceOf(HOT);
        vm.prank(HOT);
        engine.flashFillAndDraw(oid, ask, LANDING, 0);

        assertEq(usdc.balanceOf(LANDING), 0);
        assertEq(credit.freeUsdc(), 0);
        assertEq(credit.debtOf(HOT), ask);
        assertEq(eusd.balanceOf(HOT), eBefore + 5_000_000e18);
    }

    function test_flash_fill_topup_leaves_live_idle_and_landing() public {
        bytes32 oid = fill7683.openOrder(HOT, 5_000_000e18, 4_500_000e6, uint32(block.timestamp + 1 days));
        uint256 ask = 4_500_000e6;

        usdc.mint(HOT, ask);
        uint256 eBefore = eusd.balanceOf(HOT);
        vm.startPrank(HOT);
        usdc.approve(address(engine), ask);
        engine.flashFillAndDraw(oid, ask, LANDING, ask);
        vm.stopPrank();

        assertEq(usdc.balanceOf(LANDING), ask);
        assertEq(credit.freeUsdc(), 0);
        assertEq(credit.debtOf(HOT), ask);
        assertEq(eusd.balanceOf(HOT), eBefore + 5_000_000e18);
    }

    function test_flash_fill_topup_no_draw_keeps_credit_idle() public {
        bytes32 oid = fill7683.openOrder(HOT, 5_000_000e18, 4_500_000e6, uint32(block.timestamp + 1 days));
        uint256 ask = 4_500_000e6;

        usdc.mint(HOT, ask);
        vm.startPrank(HOT);
        usdc.approve(address(engine), ask);
        engine.flashFillAndDraw(oid, ask, address(0), ask);
        vm.stopPrank();

        assertEq(credit.freeUsdc(), ask);
        assertEq(credit.debtOf(HOT), 0);
        assertEq(usdc.balanceOf(LANDING), 0);
    }
}
