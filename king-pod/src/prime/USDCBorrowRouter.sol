// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";
import {CrownBoundLandingCollateral} from "./CrownBoundLandingCollateral.sol";
import {CrownPrimeCredit} from "./CrownPrimeCredit.sol";

/// @title USDCBorrowRouter
/// @notice Draws USDC loans against locked float once credit has real idle.
/// @dev Capacity from BoundLandingCollateral; cash from CrownPrimeCredit. Armed by King.
contract USDCBorrowRouter is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    CrownBoundLandingCollateral public immutable coll;
    CrownPrimeCredit public immutable credit;
    IERC20 public immutable usdc;
    address public immutable king;

    bool public armed;
    address public psm; // optional seed target
    address public landing;

    event Armed(bool on);
    event TargetsSet(address psm, address landing);
    event Drawn(uint256 amt, address indexed to);

    error NotArmed();
    error BadAmt();
    error CapacityMiss();
    error IdleMiss();

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

    /// @notice Draw `amt` USDC to `to` (default Landing). Requires armed + idle + capacity.
    function draw(uint256 amt, address to) external onlyOwner nonReentrant returns (uint256) {
        if (!armed) revert NotArmed();
        if (amt == 0) revert BadAmt();
        if (to == address(0)) {
            to = landing != address(0) ? landing : king;
        }
        if (amt > coll.borrowCapacityUsd6()) revert CapacityMiss();
        if (amt > credit.freeUsdc()) revert IdleMiss();

        credit.operatorBorrowTo(to, amt);
        emit Drawn(amt, to);
        return amt;
    }

    /// @notice Draw to PSM for exit-rail seed (owner of PSM must accept USDC via transfer — Landing/PSM EOA ok).
    function drawToPsm(uint256 amt) external onlyOwner nonReentrant returns (uint256) {
        if (!armed) revert NotArmed();
        if (psm == address(0) || amt == 0) revert BadAmt();
        if (amt > coll.borrowCapacityUsd6()) revert CapacityMiss();
        if (amt > credit.freeUsdc()) revert IdleMiss();
        credit.operatorBorrowTo(psm, amt);
        emit Drawn(amt, psm);
        return amt;
    }
}
