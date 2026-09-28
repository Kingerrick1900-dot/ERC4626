// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./lib/Core.sol";

/// @title CrownPayAdapter
/// @notice Open Money / merchant rail — eUSD pay to King-listed merchants only.
/// @dev KAR routes invoices here. No bank ACH. Restored for China Connection wire.
contract CrownPayAdapter is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable eusd;
    address public allowlist; // optional future gate
    mapping(address => bool) public merchant;
    mapping(address => bool) public puller; // RoyalCard / ops may payFrom

    event MerchantSet(address indexed merchant, bool ok);
    event PullerSet(address indexed puller, bool ok);
    event Paid(address indexed merchant, address indexed payer, uint256 amount, bytes32 indexed invoiceId);

    error BadMerchant();
    error Zero();
    error Auth();

    constructor(address eusd_, address owner_) Ownable(owner_) {
        if (eusd_ == address(0)) revert Zero();
        eusd = IERC20(eusd_);
    }

    function setMerchant(address m, bool ok) external onlyOwner {
        if (m == address(0)) revert Zero();
        merchant[m] = ok;
        emit MerchantSet(m, ok);
    }

    function setAllowlist(address a) external onlyOwner {
        allowlist = a;
    }

    function setPuller(address p, bool ok) external onlyOwner {
        if (p == address(0)) revert Zero();
        puller[p] = ok;
        emit PullerSet(p, ok);
    }

    /// @notice Pull eUSD from payer (approve first) → merchant for invoiceId.
    function pay(address merchant_, uint256 amount, bytes32 invoiceId) external nonReentrant {
        _pay(msg.sender, merchant_, amount, invoiceId);
    }

    /// @notice Owner or authorized puller (RoyalCard) pulls from pre-approved wallet.
    function payFrom(address from, address merchant_, uint256 amount, bytes32 invoiceId)
        external
        nonReentrant
    {
        if (msg.sender != owner && !puller[msg.sender]) revert Auth();
        _pay(from, merchant_, amount, invoiceId);
    }

    function _pay(address from, address merchant_, uint256 amount, bytes32 invoiceId) internal {
        if (!merchant[merchant_]) revert BadMerchant();
        if (amount == 0 || from == address(0)) revert Zero();
        eusd.safeTransferFrom(from, merchant_, amount);
        emit Paid(merchant_, from, amount, invoiceId);
    }
}
