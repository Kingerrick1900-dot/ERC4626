// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";
import {CrownBoundLandingCollateral} from "./CrownBoundLandingCollateral.sol";

/// @title CrownPrimeCredit
/// @notice USDC loan pool for prime brokerage. Capacity from BoundLandingCollateral, not ZK dust.
/// @dev Idle = balance − totalDebt. Solvers / LitePSM supply; router borrows to Landing/PSM.
contract CrownPrimeCredit is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable usdc;
    CrownBoundLandingCollateral public immutable coll;
    address public immutable king;
    address public landing;

    uint256 public totalSupplyUsdc;
    uint256 public totalDebt;

    mapping(address => uint256) public supplyOf;
    mapping(address => uint256) public debtOf; // king debt tracked under king
    mapping(address => bool) public operator;

    event LandingSet(address landing);
    event OperatorSet(address indexed op, bool on);
    event Supplied(address indexed user, uint256 amt);
    event Withdrawn(address indexed user, uint256 amt);
    event BorrowedTo(address indexed to, uint256 amt);
    event Repaid(address indexed payer, uint256 amt);

    error BadAmt();
    error Insolvent();
    error CapacityMiss();
    error IdleMiss();
    error NotOp();
    error ColdMiss();

    constructor(address usdc_, address coll_, address king_, address landing_, address owner_) Ownable(owner_) {
        require(usdc_ != address(0) && coll_ != address(0) && king_ != address(0), "ZERO");
        usdc = IERC20(usdc_);
        coll = CrownBoundLandingCollateral(coll_);
        king = king_;
        landing = landing_;
    }

    function setLanding(address landing_) external onlyOwner {
        if (landing_ == address(0)) revert BadAmt();
        landing = landing_;
        emit LandingSet(landing_);
    }

    function setOperator(address op, bool on) external onlyOwner {
        operator[op] = on;
        emit OperatorSet(op, on);
    }

    /// @notice Unmatched USDC in the pool available to borrow (cash on hand).
    function freeUsdc() public view returns (uint256) {
        return usdc.balanceOf(address(this));
    }

    function idle() public view returns (uint256) {
        return freeUsdc();
    }

    function maxBorrow() public view returns (uint256) {
        uint256 cap = coll.borrowCapacityUsd6();
        uint256 bal = usdc.balanceOf(address(this));
        return cap < bal ? cap : bal;
    }

    function supply(uint256 amt) external nonReentrant {
        if (amt == 0) revert BadAmt();
        usdc.safeTransferFrom(msg.sender, address(this), amt);
        supplyOf[msg.sender] += amt;
        totalSupplyUsdc += amt;
        emit Supplied(msg.sender, amt);
    }

    /// @notice Credit may pull USDC from a trusted feeder (LitePSM / 7683) already holding tokens.
    function supplyFrom(address from, uint256 amt) external nonReentrant {
        if (!operator[msg.sender]) revert NotOp();
        if (amt == 0) revert BadAmt();
        usdc.safeTransferFrom(from, address(this), amt);
        supplyOf[from] += amt;
        totalSupplyUsdc += amt;
        emit Supplied(from, amt);
    }

    function withdraw(uint256 amt) external nonReentrant {
        if (amt == 0 || amt > supplyOf[msg.sender]) revert BadAmt();
        // Borrowed cash already left; only unmatched balance is withdrawable.
        if (amt > usdc.balanceOf(address(this))) revert Insolvent();
        supplyOf[msg.sender] -= amt;
        totalSupplyUsdc -= amt;
        usdc.safeTransfer(msg.sender, amt);
        emit Withdrawn(msg.sender, amt);
    }

    function operatorBorrowTo(address to, uint256 amt) external nonReentrant {
        if (!operator[msg.sender]) revert NotOp();
        if (to == address(0) || amt == 0) revert BadAmt();
        if (amt > coll.borrowCapacityUsd6()) revert CapacityMiss();
        if (amt > usdc.balanceOf(address(this))) revert IdleMiss();

        debtOf[king] += amt;
        totalDebt += amt;
        coll.setReservedDebtUsd6(debtOf[king]);

        uint256 before = usdc.balanceOf(to);
        usdc.safeTransfer(to, amt);
        if (usdc.balanceOf(to) < before + amt) revert ColdMiss();
        emit BorrowedTo(to, amt);
    }

    function repay(uint256 amt) external nonReentrant {
        if (amt == 0 || amt > debtOf[king]) revert BadAmt();
        usdc.safeTransferFrom(msg.sender, address(this), amt);
        debtOf[king] -= amt;
        totalDebt -= amt;
        coll.setReservedDebtUsd6(debtOf[king]);
        emit Repaid(msg.sender, amt);
    }

    /// @notice Treasury convenience: pull from payer already approved.
    function repayFrom(address payer, uint256 amt) external nonReentrant {
        if (!operator[msg.sender] && msg.sender != payer) revert NotOp();
        if (amt == 0 || amt > debtOf[king]) revert BadAmt();
        usdc.safeTransferFrom(payer, address(this), amt);
        debtOf[king] -= amt;
        totalDebt -= amt;
        coll.setReservedDebtUsd6(debtOf[king]);
        emit Repaid(payer, amt);
    }
}
