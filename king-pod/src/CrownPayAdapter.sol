// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

/// @notice Open Money / merchant rail stub — eUSD pay to allowlisted merchants only.
/// @dev KAR routes invoices here. No bank ACH. Merchant must be King-listed.
contract CrownPayAdapter is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable eusd;
    mapping(address => bool) public merchant;
    address public allowlist; // optional CrownAllowlist

    event MerchantSet(address indexed merchant, bool ok);
    event Paid(address indexed merchant, address indexed payer, uint256 amount, bytes32 indexed invoiceId);

    error BadMerchant();
    error Zero();

    constructor(address eusd_, address owner_) Ownable(owner_) {
        eusd = IERC20(eusd_);
    }

    function setMerchant(address m, bool ok) external onlyOwner {
        merchant[m] = ok;
        emit MerchantSet(m, ok);
    }

    function setAllowlist(address a) external onlyOwner {
        allowlist = a;
    }

    /// @notice Pull eUSD from payer (approve first) → merchant for invoiceId.
    function pay(address merchant_, uint256 amount, bytes32 invoiceId) external nonReentrant {
        if (!merchant[merchant_]) revert BadMerchant();
        if (amount == 0) revert Zero();
        eusd.safeTransferFrom(msg.sender, merchant_, amount);
        emit Paid(merchant_, msg.sender, amount, invoiceId);
    }

    /// @notice Owner/ops pull from treasury wallet that pre-approved adapter.
    function payFrom(address from, address merchant_, uint256 amount, bytes32 invoiceId)
        external
        onlyOwner
        nonReentrant
    {
        if (!merchant[merchant_]) revert BadMerchant();
        if (amount == 0) revert Zero();
        eusd.safeTransferFrom(from, merchant_, amount);
        emit Paid(merchant_, from, amount, invoiceId);
    }
}
