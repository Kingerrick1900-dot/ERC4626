// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";

interface IBorders {
    function bordersSecure() external view returns (bool);
}

/// @title CrownLakalaAcquiring
/// @notice Kingdom merchant-acquiring stack — Lakala-*class* surface (mercId / termNo /
///         micropay / preorder / refund / settle), Crown-original design.
/// @dev NOT a Lakala patent fork or API clone. Conceptual parity only:
///      merchant + terminal hierarchy, NFC/auth micropay, ledger settle with MDR.
contract CrownLakalaAcquiring is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    // ── Pay modes (Crown rails — not WeChat/Alipay clones) ──────────────────
    uint8 public constant PAY_NFC = 1;
    uint8 public constant PAY_ROYAL_CARD = 2;
    uint8 public constant PAY_QR_CROWN = 3;
    uint8 public constant PAY_DIRECT = 4;

    // ── Order status ────────────────────────────────────────────────────────
    uint8 public constant ST_NONE = 0;
    uint8 public constant ST_PREORDER = 1;
    uint8 public constant ST_CAPTURED = 2;
    uint8 public constant ST_REFUNDED = 3;
    uint8 public constant ST_PARTIAL_REFUND = 4;
    uint8 public constant ST_CLOSED = 5;

    IERC20 public immutable payToken; // eUSD or USDC (18 or 6 dp — caller aware)
    address public attest; // optional borders gate
    address public royalCard; // optional RoyalCard bridge
    uint16 public defaultMdrBps; // merchant discount rate, basis points (100 = 1%)
    uint16 public constant MAX_MDR_BPS = 500; // 5% hard cap
    bool public paused;

    struct Merchant {
        address operator; // registers terminals, refunds, settles
        address settleWallet; // receives settle() payouts
        uint16 mdrBps; // 0 = use defaultMdrBps
        bool active;
        bool frozen;
        uint64 registeredAt;
        bytes32 metaHash; // off-chain KYB / DBA hash
    }

    struct Terminal {
        bytes32 mercId;
        bool active;
        bytes32 labelHash; // SoftPOS / physical POS label
        uint64 registeredAt;
    }

    struct Order {
        bytes32 mercId;
        bytes32 termNo;
        address payer;
        uint256 amount; // gross
        uint256 fee; // MDR taken at capture
        uint256 refunded; // cumulative refund gross
        uint8 payMode;
        uint8 status;
        uint64 createdAt;
        uint64 capturedAt;
        bytes32 receipt; // NFC cosign / auth-code hash
    }

    mapping(bytes32 => Merchant) public merchants; // mercId
    mapping(bytes32 => mapping(bytes32 => Terminal)) public terminals; // mercId => termNo
    mapping(bytes32 => Order) public orders; // outTradeNo
    mapping(bytes32 => uint256) public pendingSettle; // mercId => net credit (after MDR)
    mapping(bytes32 => uint256) public totalCaptured; // mercId lifecycle stats
    mapping(bytes32 => uint256) public totalSettled;
    mapping(bytes32 => uint256) public totalRefunded;
    uint256 public protocolFees; // accumulated MDR held for King sweep

    event MerchantRegistered(bytes32 indexed mercId, address operator, address settleWallet, uint16 mdrBps);
    event MerchantUpdated(bytes32 indexed mercId, address operator, address settleWallet, uint16 mdrBps, bool active);
    event MerchantFrozen(bytes32 indexed mercId, bool frozen);
    event TerminalRegistered(bytes32 indexed mercId, bytes32 indexed termNo, bytes32 labelHash);
    event TerminalActive(bytes32 indexed mercId, bytes32 indexed termNo, bool active);
    event Preordered(bytes32 indexed outTradeNo, bytes32 indexed mercId, bytes32 termNo, uint256 amount, uint8 payMode);
    event Micropaid(
        bytes32 indexed outTradeNo,
        bytes32 indexed mercId,
        bytes32 termNo,
        address payer,
        uint256 amount,
        uint256 fee,
        uint8 payMode,
        bytes32 receipt
    );
    event Captured(bytes32 indexed outTradeNo, address payer, uint256 amount, uint256 fee, bytes32 receipt);
    event Refunded(bytes32 indexed outTradeNo, uint256 amount, uint256 feeReturn, address to);
    event Closed(bytes32 indexed outTradeNo);
    event Settled(bytes32 indexed mercId, address settleWallet, uint256 net);
    event ProtocolFeesSwept(address to, uint256 amt);
    event ModulesSet(address attest, address royalCard, uint16 defaultMdrBps);
    event Paused(bool on);

    error PausedErr();
    error BadMerc();
    error BadTerm();
    error BadOrder();
    error BadAmt();
    error BadMode();
    error FrozenErr();
    error Borders();
    error NotOp();
    error Exists();
    error Status();
    error Auth();

    modifier whenNotPaused() {
        if (paused) revert PausedErr();
        _;
    }

    constructor(address payToken_, address owner_, uint16 defaultMdrBps_) Ownable(owner_) {
        require(payToken_ != address(0), "ZERO");
        require(defaultMdrBps_ <= MAX_MDR_BPS, "MDR");
        payToken = IERC20(payToken_);
        defaultMdrBps = defaultMdrBps_;
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Admin
    // ══════════════════════════════════════════════════════════════════════════

    function setModules(address attest_, address royalCard_, uint16 defaultMdrBps_) external onlyOwner {
        require(defaultMdrBps_ <= MAX_MDR_BPS, "MDR");
        attest = attest_;
        royalCard = royalCard_;
        defaultMdrBps = defaultMdrBps_;
        emit ModulesSet(attest_, royalCard_, defaultMdrBps_);
    }

    function setPaused(bool on) external onlyOwner {
        paused = on;
        emit Paused(on);
    }

    function sweepProtocolFees(address to) external onlyOwner nonReentrant {
        require(to != address(0), "ZERO");
        uint256 amt = protocolFees;
        protocolFees = 0;
        payToken.safeTransfer(to, amt);
        emit ProtocolFeesSwept(to, amt);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Merchant / terminal lifecycle
    // ══════════════════════════════════════════════════════════════════════════

    function registerMerchant(
        bytes32 mercId,
        address operator,
        address settleWallet,
        uint16 mdrBps,
        bytes32 metaHash
    ) external onlyOwner {
        if (mercId == bytes32(0) || operator == address(0) || settleWallet == address(0)) revert BadMerc();
        if (mdrBps > MAX_MDR_BPS) revert BadAmt();
        if (merchants[mercId].operator != address(0)) revert Exists();
        merchants[mercId] = Merchant({
            operator: operator,
            settleWallet: settleWallet,
            mdrBps: mdrBps,
            active: true,
            frozen: false,
            registeredAt: uint64(block.timestamp),
            metaHash: metaHash
        });
        emit MerchantRegistered(mercId, operator, settleWallet, mdrBps);
    }

    function updateMerchant(
        bytes32 mercId,
        address operator,
        address settleWallet,
        uint16 mdrBps,
        bool active
    ) external onlyOwner {
        Merchant storage m = merchants[mercId];
        if (m.operator == address(0)) revert BadMerc();
        if (operator == address(0) || settleWallet == address(0)) revert BadMerc();
        if (mdrBps > MAX_MDR_BPS) revert BadAmt();
        m.operator = operator;
        m.settleWallet = settleWallet;
        m.mdrBps = mdrBps;
        m.active = active;
        emit MerchantUpdated(mercId, operator, settleWallet, mdrBps, active);
    }

    function setMerchantFrozen(bytes32 mercId, bool on) external onlyOwner {
        if (merchants[mercId].operator == address(0)) revert BadMerc();
        merchants[mercId].frozen = on;
        emit MerchantFrozen(mercId, on);
    }

    function registerTerminal(bytes32 mercId, bytes32 termNo, bytes32 labelHash) external {
        Merchant storage m = merchants[mercId];
        if (m.operator == address(0) || !m.active) revert BadMerc();
        if (msg.sender != m.operator && msg.sender != owner) revert NotOp();
        if (termNo == bytes32(0)) revert BadTerm();
        if (terminals[mercId][termNo].registeredAt != 0) revert Exists();
        terminals[mercId][termNo] = Terminal({
            mercId: mercId,
            active: true,
            labelHash: labelHash,
            registeredAt: uint64(block.timestamp)
        });
        emit TerminalRegistered(mercId, termNo, labelHash);
    }

    function setTerminalActive(bytes32 mercId, bytes32 termNo, bool on) external {
        Merchant storage m = merchants[mercId];
        if (m.operator == address(0)) revert BadMerc();
        if (msg.sender != m.operator && msg.sender != owner) revert NotOp();
        Terminal storage t = terminals[mercId][termNo];
        if (t.registeredAt == 0) revert BadTerm();
        t.active = on;
        emit TerminalActive(mercId, termNo, on);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Preorder (主扫-class) — merchant creates unpaid order; payer captures later
    // ══════════════════════════════════════════════════════════════════════════

    function preorder(
        bytes32 mercId,
        bytes32 termNo,
        bytes32 outTradeNo,
        uint256 amount,
        uint8 payMode
    ) external whenNotPaused {
        _assertLiveRail(mercId, termNo, payMode);
        if (outTradeNo == bytes32(0) || amount == 0) revert BadAmt();
        if (orders[outTradeNo].status != ST_NONE) revert Exists();
        Merchant storage m = merchants[mercId];
        if (msg.sender != m.operator && msg.sender != owner) revert NotOp();

        orders[outTradeNo] = Order({
            mercId: mercId,
            termNo: termNo,
            payer: address(0),
            amount: amount,
            fee: 0,
            refunded: 0,
            payMode: payMode,
            status: ST_PREORDER,
            createdAt: uint64(block.timestamp),
            capturedAt: 0,
            receipt: bytes32(0)
        });
        emit Preordered(outTradeNo, mercId, termNo, amount, payMode);
    }

    /// @notice Payer fills a preorder (pull payToken → escrow, credit merchant ledger).
    function capture(bytes32 outTradeNo, bytes32 receipt) external nonReentrant whenNotPaused {
        _borders();
        Order storage o = orders[outTradeNo];
        if (o.status != ST_PREORDER) revert Status();
        Merchant storage m = merchants[o.mercId];
        if (!m.active || m.frozen) revert FrozenErr();
        Terminal storage t = terminals[o.mercId][o.termNo];
        if (!t.active) revert BadTerm();

        uint256 fee = _fee(o.mercId, o.amount);
        o.payer = msg.sender;
        o.fee = fee;
        o.status = ST_CAPTURED;
        o.capturedAt = uint64(block.timestamp);
        o.receipt = receipt;

        payToken.safeTransferFrom(msg.sender, address(this), o.amount);
        pendingSettle[o.mercId] += (o.amount - fee);
        protocolFees += fee;
        totalCaptured[o.mercId] += o.amount;

        emit Captured(outTradeNo, msg.sender, o.amount, fee, receipt);
    }

    function close(bytes32 outTradeNo) external whenNotPaused {
        Order storage o = orders[outTradeNo];
        if (o.status != ST_PREORDER) revert Status();
        Merchant storage m = merchants[o.mercId];
        if (msg.sender != m.operator && msg.sender != owner) revert NotOp();
        o.status = ST_CLOSED;
        emit Closed(outTradeNo);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Micropay (被扫-class) — single-shot NFC / RoyalCard / QR capture
    // ══════════════════════════════════════════════════════════════════════════

    /// @notice Payer-initiated micropay against live mercId+termNo.
    function micropay(
        bytes32 mercId,
        bytes32 termNo,
        bytes32 outTradeNo,
        uint256 amount,
        uint8 payMode,
        bytes32 receipt
    ) external nonReentrant whenNotPaused {
        _micropayFrom(msg.sender, msg.sender, mercId, termNo, outTradeNo, amount, payMode, receipt);
    }

    /// @notice RoyalCard / KAR bridge — only callable by wired royalCard module.
    /// @dev Pulls payToken from msg.sender (the bridge), records `payer` as card holder.
    function micropayFromCard(
        address payer,
        bytes32 mercId,
        bytes32 termNo,
        bytes32 outTradeNo,
        uint256 amount,
        bytes32 receipt
    ) external nonReentrant whenNotPaused {
        if (msg.sender != royalCard || royalCard == address(0)) revert Auth();
        _micropayFrom(payer, msg.sender, mercId, termNo, outTradeNo, amount, PAY_ROYAL_CARD, receipt);
    }

    function _micropayFrom(
        address payer,
        address tokenFrom,
        bytes32 mercId,
        bytes32 termNo,
        bytes32 outTradeNo,
        uint256 amount,
        uint8 payMode,
        bytes32 receipt
    ) internal {
        _borders();
        _assertLiveRail(mercId, termNo, payMode);
        if (outTradeNo == bytes32(0) || amount == 0 || payer == address(0)) revert BadAmt();
        if (orders[outTradeNo].status != ST_NONE) revert Exists();

        uint256 fee = _fee(mercId, amount);
        orders[outTradeNo] = Order({
            mercId: mercId,
            termNo: termNo,
            payer: payer,
            amount: amount,
            fee: fee,
            refunded: 0,
            payMode: payMode,
            status: ST_CAPTURED,
            createdAt: uint64(block.timestamp),
            capturedAt: uint64(block.timestamp),
            receipt: receipt
        });

        payToken.safeTransferFrom(tokenFrom, address(this), amount);
        pendingSettle[mercId] += (amount - fee);
        protocolFees += fee;
        totalCaptured[mercId] += amount;

        emit Micropaid(outTradeNo, mercId, termNo, payer, amount, fee, payMode, receipt);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Refund / revoke
    // ══════════════════════════════════════════════════════════════════════════

    /// @notice Full or partial refund of a captured order. Returns gross to payer;
    ///         clawback from pendingSettle (and protocolFees for proportional MDR).
    function refund(bytes32 outTradeNo, uint256 amount) external nonReentrant whenNotPaused {
        Order storage o = orders[outTradeNo];
        if (o.status != ST_CAPTURED && o.status != ST_PARTIAL_REFUND) revert Status();
        Merchant storage m = merchants[o.mercId];
        if (msg.sender != m.operator && msg.sender != owner) revert NotOp();
        if (amount == 0 || amount + o.refunded > o.amount) revert BadAmt();

        // Proportional fee return
        uint256 feeReturn = (o.fee * amount) / o.amount;
        uint256 netClaw = amount - feeReturn;
        if (pendingSettle[o.mercId] < netClaw) revert BadAmt(); // must settle after refunds or keep float
        if (protocolFees < feeReturn) revert BadAmt();

        pendingSettle[o.mercId] -= netClaw;
        protocolFees -= feeReturn;
        o.refunded += amount;
        totalRefunded[o.mercId] += amount;
        o.status = (o.refunded == o.amount) ? ST_REFUNDED : ST_PARTIAL_REFUND;

        payToken.safeTransfer(o.payer, amount);
        emit Refunded(outTradeNo, amount, feeReturn, o.payer);
    }

    /// @notice Convenience: full refund of remaining capturable amount.
    function revoke(bytes32 outTradeNo) external nonReentrant whenNotPaused {
        Order storage o = orders[outTradeNo];
        if (o.status != ST_CAPTURED && o.status != ST_PARTIAL_REFUND) revert Status();
        Merchant storage m = merchants[o.mercId];
        if (msg.sender != m.operator && msg.sender != owner) revert NotOp();
        uint256 left = o.amount - o.refunded;
        // inline refund body to avoid external self-call / reentrancy flag
        uint256 feeReturn = (o.fee * left) / o.amount;
        uint256 netClaw = left - feeReturn;
        if (pendingSettle[o.mercId] < netClaw || protocolFees < feeReturn) revert BadAmt();
        pendingSettle[o.mercId] -= netClaw;
        protocolFees -= feeReturn;
        o.refunded += left;
        totalRefunded[o.mercId] += left;
        o.status = ST_REFUNDED;
        payToken.safeTransfer(o.payer, left);
        emit Refunded(outTradeNo, left, feeReturn, o.payer);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Settle
    // ══════════════════════════════════════════════════════════════════════════

    function settle(bytes32 mercId) external nonReentrant whenNotPaused {
        Merchant storage m = merchants[mercId];
        if (m.operator == address(0)) revert BadMerc();
        if (msg.sender != m.operator && msg.sender != owner && msg.sender != m.settleWallet) revert NotOp();
        if (m.frozen) revert FrozenErr();
        uint256 net = pendingSettle[mercId];
        if (net == 0) revert BadAmt();
        pendingSettle[mercId] = 0;
        totalSettled[mercId] += net;
        payToken.safeTransfer(m.settleWallet, net);
        emit Settled(mercId, m.settleWallet, net);
    }

    function settleBatch(bytes32[] calldata mercIds) external nonReentrant whenNotPaused {
        uint256 n = mercIds.length;
        for (uint256 i; i < n; ++i) {
            bytes32 mercId = mercIds[i];
            Merchant storage m = merchants[mercId];
            if (m.operator == address(0) || m.frozen) continue;
            if (msg.sender != m.operator && msg.sender != owner && msg.sender != m.settleWallet) continue;
            uint256 net = pendingSettle[mercId];
            if (net == 0) continue;
            pendingSettle[mercId] = 0;
            totalSettled[mercId] += net;
            payToken.safeTransfer(m.settleWallet, net);
            emit Settled(mercId, m.settleWallet, net);
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Views (tradequery-class)
    // ══════════════════════════════════════════════════════════════════════════

    function tradeQuery(bytes32 outTradeNo) external view returns (Order memory o) {
        o = orders[outTradeNo];
    }

    function effectiveMdrBps(bytes32 mercId) public view returns (uint16) {
        uint16 b = merchants[mercId].mdrBps;
        return b == 0 ? defaultMdrBps : b;
    }

    function merchantStats(bytes32 mercId)
        external
        view
        returns (uint256 pending, uint256 captured, uint256 settled, uint256 refundedAmt)
    {
        return (pendingSettle[mercId], totalCaptured[mercId], totalSettled[mercId], totalRefunded[mercId]);
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Internals
    // ══════════════════════════════════════════════════════════════════════════

    function _borders() internal view {
        if (attest != address(0) && !IBorders(attest).bordersSecure()) revert Borders();
    }

    function _assertLiveRail(bytes32 mercId, bytes32 termNo, uint8 payMode) internal view {
        if (payMode < PAY_NFC || payMode > PAY_DIRECT) revert BadMode();
        Merchant storage m = merchants[mercId];
        if (m.operator == address(0) || !m.active) revert BadMerc();
        if (m.frozen) revert FrozenErr();
        Terminal storage t = terminals[mercId][termNo];
        if (t.registeredAt == 0 || !t.active) revert BadTerm();
    }

    function _fee(bytes32 mercId, uint256 amount) internal view returns (uint256) {
        return (amount * effectiveMdrBps(mercId)) / 10_000;
    }
}
