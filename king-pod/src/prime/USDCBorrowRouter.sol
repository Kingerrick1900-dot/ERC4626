// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";
import {CrownBoundLandingCollateral} from "./CrownBoundLandingCollateral.sol";
import {CrownPrimeCredit} from "./CrownPrimeCredit.sol";
import {CrownPrimeSafeParams} from "./CrownPrimeSafeParams.sol";

/// @title USDCBorrowRouter
/// @notice Draws USDC against locked float once credit has real idle. King-arm gated.
/// @dev `kingEmergencyDraw` — one-shot ≤ $2M, bypasses `armed` only; still needs cash + capacity.
contract USDCBorrowRouter is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    CrownBoundLandingCollateral public immutable coll;
    CrownPrimeCredit public immutable credit;
    IERC20 public immutable usdc;
    address public immutable king;

    bool public armed;
    address public psm;
    address public landing;

    bool public emergencyUsed;
    uint256 public emergencyDrawn;
    uint256 public constant EMERGENCY_CAP = CrownPrimeSafeParams.EMERGENCY_CAP_USD6;
    uint256 public constant MAX_DEBT = CrownPrimeSafeParams.MAX_DEBT_USD6;

    event Armed(bool on);
    event TargetsSet(address psm, address landing);
    event Drawn(uint256 amt, address indexed to);
    event EmergencyDrawn(uint256 amt, address indexed to);

    error NotArmed();
    error BadAmt();
    error CapacityMiss();
    error IdleMiss();
    error EmergencyUsed();
    error EmergencyCap();
    error DebtCap();
    error KingOnly();

    constructor(address coll_, address credit_, address usdc_, address king_, address owner_) Ownable(owner_) {
        require(coll_ != address(0) && credit_ != address(0) && usdc_ != address(0) && king_ != address(0), "ZERO");
        coll = CrownBoundLandingCollateral(coll_);
        credit = CrownPrimeCredit(credit_);
        usdc = IERC20(usdc_);
        king = king_;
    }

    function setArmed(bool on) external onlyOwner {
        armed = on;
        emit Armed(on);
    }

    function setTargets(address psm_, address landing_) external onlyOwner {
        psm = psm_;
        landing = landing_;
        emit TargetsSet(psm_, landing_);
    }

    function maxDraw() public view returns (uint256) {
        return credit.maxBorrow();
    }

    function totalDebtUsd6() public view returns (uint256) {
        return credit.debtOf(king);
    }

    /// @notice Draw `amt` USDC to `to` (default Landing). Requires armed + idle + capacity + debt cap.
    function draw(uint256 amt, address to) external onlyOwner nonReentrant returns (uint256) {
        if (!armed) revert NotArmed();
        if (amt == 0) revert BadAmt();
        if (to == address(0)) {
            to = landing != address(0) ? landing : king;
        }
        _borrow(to, amt);
        emit Drawn(amt, to);
        return amt;
    }

    function drawToPsm(uint256 amt) external onlyOwner nonReentrant returns (uint256) {
        if (!armed) revert NotArmed();
        if (psm == address(0) || amt == 0) revert BadAmt();
        _borrow(psm, amt);
        emit Drawn(amt, psm);
        return amt;
    }

    /// @notice One-shot King draw ≤ $2M. Bypasses `armed` only — still needs free USDC + capacity.
    /// @dev Does not invent dollars. Use after 7683/LitePSM sales land cash in credit, before full arm.
    function kingEmergencyDraw(uint256 amt) external nonReentrant returns (uint256) {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        if (emergencyUsed) revert EmergencyUsed();
        if (amt == 0) revert BadAmt();
        if (amt > EMERGENCY_CAP) revert EmergencyCap();

        address to = landing != address(0) ? landing : king;
        _borrow(to, amt);

        emergencyUsed = true;
        emergencyDrawn = amt;
        emit EmergencyDrawn(amt, to);
        return amt;
    }

    function _borrow(address to, uint256 amt) internal {
        if (amt > coll.borrowCapacityUsd6()) revert CapacityMiss();
        if (amt > credit.freeUsdc()) revert IdleMiss();
        if (credit.debtOf(king) + amt > MAX_DEBT) revert DebtCap();
        credit.operatorBorrowTo(to, amt);
    }
}
