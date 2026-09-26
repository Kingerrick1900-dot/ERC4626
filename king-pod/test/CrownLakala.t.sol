// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {CrownLakalaAcquiring} from "../src/china/CrownLakalaAcquiring.sol";
import {CrownLakalaCardBridge} from "../src/china/CrownLakalaCardBridge.sol";
import {RoyalCard} from "../src/royal/RoyalCard.sol";

contract MockPayToken {
    string public name = "Mock eUSD";
    string public symbol = "MeUSD";
    uint8 public decimals = 18;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
        totalSupply += amt;
    }

    function approve(address spender, uint256 amt) external returns (bool) {
        allowance[msg.sender][spender] = amt;
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
        require(balanceOf[from] >= amt, "BAL");
        if (a != type(uint256).max) allowance[from][msg.sender] = a - amt;
        balanceOf[from] -= amt;
        balanceOf[to] += amt;
        return true;
    }
}

contract MockBorders {
    bool public ok = true;
    function bordersSecure() external view returns (bool) {
        return ok;
    }
    function set(bool v) external {
        ok = v;
    }
}

contract CrownLakalaTest is Test {
    MockPayToken token;
    MockBorders borders;
    CrownLakalaAcquiring acq;
    CrownLakalaCardBridge bridge;
    RoyalCard card;

    address king;
    address op;
    address settle;
    address payer;

    bytes32 mercId = keccak256("MERC-CROWN-001");
    bytes32 termNo = keccak256("TERM-SOFTPOS-01");
    bytes32 cardId = keccak256("CARD-001");

    uint256 constant ONE = 1e18;
    uint8 constant PAY_NFC = 1;
    uint8 constant PAY_ROYAL_CARD = 2;
    uint8 constant PAY_QR_CROWN = 3;
    uint8 constant PAY_DIRECT = 4;
    uint8 constant ST_PREORDER = 1;
    uint8 constant ST_CAPTURED = 2;
    uint8 constant ST_REFUNDED = 3;
    uint8 constant ST_PARTIAL_REFUND = 4;
    uint8 constant ST_CLOSED = 5;

    function setUp() public {
        king = makeAddr("king");
        op = makeAddr("op");
        settle = makeAddr("settle");
        payer = makeAddr("payer");

        token = new MockPayToken();
        borders = new MockBorders();
        acq = new CrownLakalaAcquiring(address(token), king, 100); // 1% default MDR
        bridge = new CrownLakalaCardBridge(king);
        card = new RoyalCard(address(token), king);

        vm.startPrank(king);
        acq.setModules(address(borders), address(bridge), 100);
        acq.registerMerchant(mercId, op, settle, 0, keccak256("kyb"));
        bridge.wire(address(card), address(acq), false);
        card.issue(cardId, payer, keccak256("nfc-pubkey"), 10_000 * ONE);
        vm.stopPrank();

        vm.prank(op);
        acq.registerTerminal(mercId, termNo, keccak256("softpos-label"));

        token.mint(payer, 100_000 * ONE);
    }

    function test_micropay_settle_mdr() public {
        uint256 amt = 1000 * ONE;
        bytes32 oto = keccak256("oto-1");

        vm.startPrank(payer);
        token.approve(address(acq), amt);
        acq.micropay(mercId, termNo, oto, amt, PAY_NFC, keccak256("tap-1"));
        vm.stopPrank();

        uint256 fee = amt / 100; // 1%
        (uint256 pending, uint256 captured,,) = acq.merchantStats(mercId);
        assertEq(captured, amt);
        assertEq(pending, amt - fee);
        assertEq(acq.protocolFees(), fee);

        vm.prank(op);
        acq.settle(mercId);
        assertEq(token.balanceOf(settle), amt - fee);
        assertEq(acq.pendingSettle(mercId), 0);

        vm.prank(king);
        acq.sweepProtocolFees(king);
        assertEq(token.balanceOf(king), fee);
    }

    function test_preorder_capture_close() public {
        bytes32 oto = keccak256("oto-pre");
        uint256 amt = 50 * ONE;

        vm.prank(op);
        acq.preorder(mercId, termNo, oto, amt, PAY_QR_CROWN);

        CrownLakalaAcquiring.Order memory q = acq.tradeQuery(oto);
        assertEq(q.status, ST_PREORDER);
        assertEq(q.amount, amt);

        // close unpaid
        bytes32 oto2 = keccak256("oto-pre-close");
        vm.prank(op);
        acq.preorder(mercId, termNo, oto2, amt, PAY_QR_CROWN);
        vm.prank(op);
        acq.close(oto2);
        assertEq(acq.tradeQuery(oto2).status, ST_CLOSED);

        // capture paid
        vm.startPrank(payer);
        token.approve(address(acq), amt);
        acq.capture(oto, keccak256("cap-1"));
        vm.stopPrank();
        q = acq.tradeQuery(oto);
        assertEq(q.payer, payer);
        assertEq(q.fee, amt / 100);
        assertEq(q.status, ST_CAPTURED);
    }

    function test_refund_and_revoke() public {
        uint256 amt = 200 * ONE;
        bytes32 oto = keccak256("oto-ref");

        vm.startPrank(payer);
        token.approve(address(acq), amt);
        acq.micropay(mercId, termNo, oto, amt, PAY_DIRECT, bytes32(0));
        vm.stopPrank();

        uint256 balBefore = token.balanceOf(payer);
        vm.prank(op);
        acq.refund(oto, 50 * ONE);
        assertEq(token.balanceOf(payer) - balBefore, 50 * ONE);

        CrownLakalaAcquiring.Order memory q = acq.tradeQuery(oto);
        assertEq(q.refunded, 50 * ONE);
        assertEq(q.status, ST_PARTIAL_REFUND);

        vm.prank(op);
        acq.revoke(oto);
        q = acq.tradeQuery(oto);
        assertEq(q.refunded, amt);
        assertEq(q.status, ST_REFUNDED);
        assertEq(acq.pendingSettle(mercId), 0);
        assertEq(acq.protocolFees(), 0);
    }

    function test_card_bridge_micropay() public {
        uint256 amt = 25 * ONE;
        bytes32 oto = keccak256("oto-card");

        vm.startPrank(payer);
        token.approve(address(bridge), amt);
        bridge.payWithCard(cardId, mercId, termNo, oto, amt, keccak256("nfc-cosign"));
        vm.stopPrank();

        CrownLakalaAcquiring.Order memory q = acq.tradeQuery(oto);
        assertEq(q.payer, payer);
        assertEq(q.amount, amt);
        assertEq(q.payMode, PAY_ROYAL_CARD);
        assertEq(q.status, ST_CAPTURED);
    }

    function test_frozen_merchant_blocks_pay() public {
        vm.prank(king);
        acq.setMerchantFrozen(mercId, true);

        vm.startPrank(payer);
        token.approve(address(acq), ONE);
        vm.expectRevert(CrownLakalaAcquiring.FrozenErr.selector);
        acq.micropay(mercId, termNo, keccak256("x"), ONE, PAY_NFC, bytes32(0));
        vm.stopPrank();
    }

    function test_borders_gate() public {
        borders.set(false);
        vm.startPrank(payer);
        token.approve(address(acq), ONE);
        vm.expectRevert(CrownLakalaAcquiring.Borders.selector);
        acq.micropay(mercId, termNo, keccak256("b"), ONE, PAY_NFC, bytes32(0));
        vm.stopPrank();
    }

    function test_pause() public {
        vm.prank(king);
        acq.setPaused(true);
        vm.startPrank(payer);
        token.approve(address(acq), ONE);
        vm.expectRevert(CrownLakalaAcquiring.PausedErr.selector);
        acq.micropay(mercId, termNo, keccak256("p"), ONE, PAY_NFC, bytes32(0));
        vm.stopPrank();
    }

    function test_custom_mdr() public {
        bytes32 m2 = keccak256("MERC-2");
        bytes32 t2 = keccak256("TERM-2");
        vm.startPrank(king);
        acq.registerMerchant(m2, op, settle, 250, bytes32(0)); // 2.5%
        vm.stopPrank();
        vm.prank(op);
        acq.registerTerminal(m2, t2, bytes32(0));

        uint256 amt = 1000 * ONE;
        vm.startPrank(payer);
        token.approve(address(acq), amt);
        acq.micropay(m2, t2, keccak256("mdr"), amt, PAY_NFC, bytes32(0));
        vm.stopPrank();

        assertEq(acq.protocolFees(), (amt * 250) / 10_000);
        (uint256 pending,,,) = acq.merchantStats(m2);
        assertEq(pending, amt - (amt * 250) / 10_000);
    }

    function test_settle_batch() public {
        bytes32 m2 = keccak256("MERC-BATCH");
        bytes32 t2 = keccak256("TERM-B");
        vm.prank(king);
        acq.registerMerchant(m2, op, settle, 0, bytes32(0));
        vm.prank(op);
        acq.registerTerminal(m2, t2, bytes32(0));

        vm.startPrank(payer);
        token.approve(address(acq), 300 * ONE);
        acq.micropay(mercId, termNo, keccak256("b1"), 100 * ONE, PAY_NFC, bytes32(0));
        acq.micropay(m2, t2, keccak256("b2"), 200 * ONE, PAY_NFC, bytes32(0));
        vm.stopPrank();

        bytes32[] memory ids = new bytes32[](2);
        ids[0] = mercId;
        ids[1] = m2;
        vm.prank(op);
        acq.settleBatch(ids);

        assertEq(acq.pendingSettle(mercId), 0);
        assertEq(acq.pendingSettle(m2), 0);
        assertEq(token.balanceOf(settle), (100 * ONE + 200 * ONE) * 99 / 100);
    }

    function test_duplicate_out_trade_reverts() public {
        vm.startPrank(payer);
        token.approve(address(acq), 2 * ONE);
        acq.micropay(mercId, termNo, keccak256("dup"), ONE, PAY_NFC, bytes32(0));
        vm.expectRevert(CrownLakalaAcquiring.Exists.selector);
        acq.micropay(mercId, termNo, keccak256("dup"), ONE, PAY_NFC, bytes32(0));
        vm.stopPrank();
    }
}
