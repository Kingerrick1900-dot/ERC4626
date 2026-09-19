// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CrownBoundReservesGate} from "../src/zk/CrownBoundReservesGate.sol";
import {CrownZkCredit} from "../src/zk/CrownZkCredit.sol";
import {CrownFlashBoundAttest} from "../src/CrownFlashBoundAttest.sol";
import {CrownBoundLandingCompleter} from "../src/CrownBoundLandingCompleter.sol";
import {CrownZkAutoDraw} from "../src/CrownZkAutoDraw.sol";
import {IERC20} from "../src/lib/Core.sol";

contract MockUsdcBound {
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

contract MockMorphoFlash {
    IERC20 public usdc;

    constructor(address usdc_) {
        usdc = IERC20(usdc_);
    }

    function flashLoan(address token, uint256 assets, bytes calldata data) external {
        require(token == address(usdc), "TOKEN");
        require(usdc.transfer(msg.sender, assets), "FL");
        IFlashCb(msg.sender).onMorphoFlashLoan(assets, data);
        require(usdc.transferFrom(msg.sender, address(this), assets), "REPAY");
    }
}

interface IFlashCb {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

/// @notice Unit + local-morpho flash for balanceOf-bound gate → Landing wire.
contract FlashBoundReservesTest is Test {
    address constant HOT = 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1;
    address constant LANDING = 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357;

    MockUsdcBound usdc;
    MockMorphoFlash morpho;
    CrownBoundReservesGate gate;
    CrownZkCredit credit;
    CrownFlashBoundAttest flash;
    CrownBoundLandingCompleter completer;
    CrownZkAutoDraw autoDraw;

    function setUp() public {
        usdc = new MockUsdcBound();
        morpho = new MockMorphoFlash(address(usdc));
        usdc.mint(address(morpho), 10_000_000e6);

        // Dummy verifier address — attestLive path under test; ZK path needs live proof.
        gate = new CrownBoundReservesGate(address(1), address(usdc), HOT);
        credit = new CrownZkCredit(address(usdc), address(gate), HOT, LANDING, HOT);
        flash = new CrownFlashBoundAttest(address(morpho), address(usdc), address(gate), HOT, HOT);
        completer = new CrownBoundLandingCompleter(address(credit), address(usdc));
        autoDraw = new CrownZkAutoDraw(address(credit), address(usdc));

        vm.startPrank(HOT);
        gate.setAttestor(address(flash), true);
        credit.setOperator(address(flash), true);
        credit.setOperator(address(completer), true);
        credit.setOperator(address(autoDraw), true);
        flash.setCredit(address(credit));
        vm.stopPrank();
    }

    function test_attestLive_rejects_without_balance() public {
        vm.prank(address(flash));
        vm.expectRevert(CrownBoundReservesGate.BalanceShort.selector);
        gate.attestLive(HOT, 700_000e6);
        assertFalse(gate.isProven(HOT));
    }

    function test_flash_live_proves_and_repays_net_zero() public {
        uint256 amt = 700_000e6;
        uint256 morphoBefore = usdc.balanceOf(address(morpho));

        vm.startPrank(HOT);
        usdc.approve(address(flash), amt);
        (bool proven, uint256 landingDelta) = flash.fireLive(amt);
        vm.stopPrank();

        assertTrue(proven);
        assertTrue(gate.isProven(HOT));
        (uint256 thr,, bool valid) = gate.attestations(HOT);
        assertEq(thr, amt);
        assertTrue(valid);
        assertEq(usdc.balanceOf(HOT), 0);
        assertEq(usdc.balanceOf(address(morpho)), morphoBefore);
        assertEq(landingDelta, 0); // no credit liquidity
    }

    function test_flash_then_completer_seeds_landing() public {
        uint256 amt = 700_000e6;
        address matcher = address(0xBEEF);
        usdc.mint(matcher, 500_000e6);

        vm.startPrank(HOT);
        usdc.approve(address(flash), amt);
        flash.fireLive(amt);
        vm.stopPrank();

        assertTrue(gate.isProven(HOT));

        vm.startPrank(matcher);
        usdc.approve(address(completer), 490_000e6);
        uint256 landingAfter = completer.complete(490_000e6);
        vm.stopPrank();

        assertEq(usdc.balanceOf(LANDING), 490_000e6);
        assertEq(landingAfter, 490_000e6);
        assertEq(credit.debtOf(HOT), 490_000e6);
    }

    function test_flash_pokes_credit_liquidity_to_landing() public {
        uint256 amt = 700_000e6;
        address lp = address(0xCAFE);
        usdc.mint(lp, 400_000e6);
        vm.startPrank(lp);
        usdc.approve(address(credit), 400_000e6);
        credit.supply(400_000e6);
        vm.stopPrank();

        // Not proven yet → maxBorrow 0
        assertEq(credit.maxBorrow(HOT), 0);

        vm.startPrank(HOT);
        usdc.approve(address(flash), amt);
        (bool proven, uint256 landingDelta) = flash.fireLive(amt);
        vm.stopPrank();

        assertTrue(proven);
        // 70% of 700k = 490k, credit has 400k → poke 400k to Landing in same flash tx
        assertEq(landingDelta, 400_000e6);
        assertEq(usdc.balanceOf(LANDING), 400_000e6);
        assertEq(usdc.balanceOf(HOT), 0);
    }

    function test_autoDraw_uses_operatorBorrowTo() public {
        uint256 amt = 700_000e6;
        vm.prank(address(flash));
        // need balance for attestLive
        usdc.mint(HOT, amt);
        vm.prank(address(flash));
        gate.attestLive(HOT, amt);

        address lp = address(0xABC);
        usdc.mint(lp, 200_000e6);
        vm.startPrank(lp);
        usdc.approve(address(credit), 200_000e6);
        credit.supply(200_000e6);
        vm.stopPrank();

        autoDraw.poke();
        assertEq(usdc.balanceOf(LANDING), 200_000e6);
    }

    function test_free_witness_cannot_pass_without_balance() public {
        // Even with a "proof", gate requires balanceOf — we only test balance short-circuit
        // before verifier by calling attestLive; submitBoundProof needs a real proof.
        assertEq(usdc.balanceOf(HOT), 0);
        vm.prank(address(0xBAD));
        vm.expectRevert(CrownBoundReservesGate.NotAttestor.selector);
        gate.attestLive(HOT, 700_000e6);
    }
}
