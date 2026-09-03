// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";
import {CrownPrimeCredit} from "./CrownPrimeCredit.sol";
import {USDCBorrowRouter} from "./USDCBorrowRouter.sol";

/// @title CrownZkAutoDraw
/// @notice One-shot: pull USDC from king → supply live credit → arm router → draw to Landing.
/// @dev King's law: debt only when cash stays as spendable USDC on Landing. No flash.
///      Router must be owned by this contract OR king calls FireFillCreditDrawCast.sh instead.
contract CrownZkAutoDraw is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable usdc;
    CrownPrimeCredit public immutable credit;
    USDCBorrowRouter public immutable router;
    address public immutable king;
    address public immutable landing;

    event FilledDrawn(uint256 supplied, uint256 drawn, uint256 landingBal);

    error KingOnly();
    error BadAmt();
    error Empty();

    constructor(
        address usdc_,
        address credit_,
        address router_,
        address king_,
        address landing_,
        address owner_
    ) Ownable(owner_) {
        require(usdc_ != address(0) && credit_ != address(0) && router_ != address(0), "ZERO");
        require(king_ != address(0) && landing_ != address(0), "ZERO");
        usdc = IERC20(usdc_);
        credit = CrownPrimeCredit(credit_);
        router = USDCBorrowRouter(router_);
        king = king_;
        landing = landing_;
        usdc.safeApprove(credit_, type(uint256).max);
    }

    /// @notice Supply `amt` from caller into credit. King arms+draws via cast (router owner = HOT).
    function fillOnly(uint256 amt) external nonReentrant {
        if (msg.sender != king && msg.sender != owner) revert KingOnly();
        if (amt == 0) revert BadAmt();
        usdc.safeTransferFrom(msg.sender, address(this), amt);
        credit.supply(amt);
        emit FilledDrawn(amt, 0, usdc.balanceOf(landing));
    }
}
