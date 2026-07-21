// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";
import {CrownZkReservesGate} from "./CrownZkReservesGate.sol";

/// @notice Borrow USDC against ZK-proven reserves (≥ $700k attestation).
/// @dev Counterparty / King book: suppliers deposit USDC; proven subject may borrow up to LLTV of attested threshold.
contract CrownZkCredit is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable usdc;
    CrownZkReservesGate public immutable gate;
    address public immutable king;

    uint256 public lltv = 700000000000000000; // 70% of attested threshold
    uint256 public totalSupplyUsdc;
    uint256 public totalDebt;

    mapping(address => uint256) public supplyOf;
    mapping(address => uint256) public debtOf;

    event Supplied(address indexed user, uint256 amt);
    event Withdrawn(address indexed user, uint256 amt);
    event Borrowed(address indexed user, uint256 amt);
    event BorrowedTo(address indexed user, address indexed to, uint256 amt);
    event Repaid(address indexed user, uint256 amt);

    error BadAmt();
    error NotProven();
    error Unsafe();
    error Insolvent();
    error ColdMiss();

    constructor(address usdc_, address gate_, address king_, address owner_) Ownable(owner_) {
        usdc = IERC20(usdc_);
        gate = CrownZkReservesGate(gate_);
        king = king_;
    }

    function setLltv(uint256 lltv_) external onlyOwner {
        if (lltv_ == 0 || lltv_ > 1e18) revert BadAmt();
        lltv = lltv_;
    }

    function supply(uint256 amt) external nonReentrant {
        if (amt == 0) revert BadAmt();
        usdc.safeTransferFrom(msg.sender, address(this), amt);
        supplyOf[msg.sender] += amt;
        totalSupplyUsdc += amt;
        emit Supplied(msg.sender, amt);
    }

    function withdraw(uint256 amt) external nonReentrant {
        if (amt == 0 || amt > supplyOf[msg.sender]) revert BadAmt();
        uint256 free = totalSupplyUsdc - totalDebt;
        if (amt > free) revert Insolvent();
        supplyOf[msg.sender] -= amt;
        totalSupplyUsdc -= amt;
        usdc.safeTransfer(msg.sender, amt);
        emit Withdrawn(msg.sender, amt);
    }

    /// @notice Borrow against ZK-proven reserves. Cap = attested threshold * LLTV.
    function borrow(uint256 amt) external nonReentrant {
        _borrowTo(msg.sender, msg.sender, amt);
    }

    /// @notice Atomic cold-or-revert: USDC goes to `to` (Landing) in one tx. Fail → full revert, no debt.
    function borrowTo(address to, uint256 amt) external nonReentrant {
        if (to == address(0)) revert BadAmt();
        _borrowTo(msg.sender, to, amt);
    }

    function _borrowTo(address borrower, address to, uint256 amt) internal {
        if (amt == 0) revert BadAmt();
        if (!gate.isProven(borrower)) revert NotProven();
        (uint256 threshold,,) = _att(borrower);
        uint256 cap = (threshold * lltv) / 1e18;
        debtOf[borrower] += amt;
        totalDebt += amt;
        if (debtOf[borrower] > cap) revert Unsafe();
        if (amt > usdc.balanceOf(address(this))) revert Insolvent();
        uint256 before = usdc.balanceOf(to);
        usdc.safeTransfer(to, amt);
        if (usdc.balanceOf(to) < before + amt) revert ColdMiss();
        emit Borrowed(borrower, amt);
        if (to != borrower) emit BorrowedTo(borrower, to, amt);
    }

    function repay(uint256 amt) external nonReentrant {
        if (amt == 0 || amt > debtOf[msg.sender]) revert BadAmt();
        usdc.safeTransferFrom(msg.sender, address(this), amt);
        debtOf[msg.sender] -= amt;
        totalDebt -= amt;
        emit Repaid(msg.sender, amt);
    }

    function maxBorrow(address user) external view returns (uint256) {
        if (!gate.isProven(user)) return 0;
        (uint256 threshold,,) = _att(user);
        uint256 cap = (threshold * lltv) / 1e18;
        uint256 d = debtOf[user];
        if (d >= cap) return 0;
        uint256 room = cap - d;
        uint256 bal = usdc.balanceOf(address(this));
        return room < bal ? room : bal;
    }

    function _att(address user) internal view returns (uint256 threshold, uint256 provenAt, bool valid) {
        return gate.attestations(user);
    }
}
