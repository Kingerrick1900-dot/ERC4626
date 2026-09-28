// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

/// @title CrownOpenMoney
/// @notice Invoice rail for Kingdom merchants — eUSD settle, optional USDC view token.
contract CrownOpenMoney is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable eusd;
    IERC20 public immutable usdc; // optional quote; may be address(0)
    mapping(address => bool) public merchant;

    struct Invoice {
        address merchant;
        address payer;
        uint256 amount;
        bool paid;
        bool active;
    }

    mapping(bytes32 => Invoice) public invoices;

    event MerchantSet(address indexed merchant, bool ok);
    event InvoiceCreated(bytes32 indexed id, address merchant, address payer, uint256 amount);
    event InvoicePaid(bytes32 indexed id, address payer, uint256 amount);

    error BadMerchant();
    error BadInvoice();
    error Zero();

    constructor(address eusd_, address usdc_, address owner_) Ownable(owner_) {
        if (eusd_ == address(0)) revert Zero();
        eusd = IERC20(eusd_);
        usdc = IERC20(usdc_);
    }

    function setMerchant(address m, bool ok) external onlyOwner {
        if (m == address(0)) revert Zero();
        merchant[m] = ok;
        emit MerchantSet(m, ok);
    }

    function createInvoice(bytes32 id, address merchant_, address payer, uint256 amount) external {
        if (!merchant[merchant_] && msg.sender != owner) revert BadMerchant();
        if (msg.sender != merchant_ && msg.sender != owner) revert BadMerchant();
        if (id == bytes32(0) || amount == 0) revert Zero();
        if (invoices[id].active) revert BadInvoice();
        invoices[id] = Invoice({merchant: merchant_, payer: payer, amount: amount, paid: false, active: true});
        emit InvoiceCreated(id, merchant_, payer, amount);
    }

    function payInvoice(bytes32 id) external nonReentrant {
        Invoice storage inv = invoices[id];
        if (!inv.active || inv.paid) revert BadInvoice();
        if (inv.payer != address(0) && msg.sender != inv.payer) revert BadInvoice();
        inv.paid = true;
        eusd.safeTransferFrom(msg.sender, inv.merchant, inv.amount);
        emit InvoicePaid(id, msg.sender, inv.amount);
    }
}
