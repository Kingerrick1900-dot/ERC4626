// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

/// @notice Open Money Stack fork — global commerce invoices in eUSD/USDC without bank ACH.
/// @dev Merchants allowlisted. InvoiceId binds off-chain cart to on-chain settlement.
contract CrownOpenMoney is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable eusd;
    IERC20 public immutable usdc;

    mapping(address => bool) public merchant;
    mapping(bytes32 => Invoice) public invoices;

    struct Invoice {
        address merchant;
        address token; // eusd or usdc
        uint256 amount;
        address payer;
        bool paid;
        uint64 createdAt;
    }

    event MerchantSet(address indexed m, bool ok);
    event InvoiceCreated(bytes32 indexed id, address indexed merchant, address token, uint256 amount);
    event InvoicePaid(bytes32 indexed id, address indexed payer, uint256 amount);

    error BadMerchant();
    error BadInvoice();
    error AlreadyPaid();
    error Zero();

    constructor(address eusd_, address usdc_, address owner_) Ownable(owner_) {
        eusd = IERC20(eusd_);
        usdc = IERC20(usdc_);
    }

    function setMerchant(address m, bool ok) external onlyOwner {
        merchant[m] = ok;
        emit MerchantSet(m, ok);
    }

    function createInvoice(bytes32 id, address merchant_, address token, uint256 amount) external onlyOwner {
        if (!merchant[merchant_]) revert BadMerchant();
        if (amount == 0) revert Zero();
        require(token == address(eusd) || token == address(usdc), "TOKEN");
        require(invoices[id].createdAt == 0, "EXISTS");
        invoices[id] = Invoice({
            merchant: merchant_,
            token: token,
            amount: amount,
            payer: address(0),
            paid: false,
            createdAt: uint64(block.timestamp)
        });
        emit InvoiceCreated(id, merchant_, token, amount);
    }

    /// @notice Payer approves token then settles invoice.
    function payInvoice(bytes32 id) external nonReentrant {
        Invoice storage inv = invoices[id];
        if (inv.createdAt == 0) revert BadInvoice();
        if (inv.paid) revert AlreadyPaid();
        inv.paid = true;
        inv.payer = msg.sender;
        IERC20(inv.token).safeTransferFrom(msg.sender, inv.merchant, inv.amount);
        emit InvoicePaid(id, msg.sender, inv.amount);
    }
}
