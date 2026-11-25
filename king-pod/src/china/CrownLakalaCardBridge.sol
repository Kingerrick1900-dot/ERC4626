// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";

interface IRoyalCardSpend {
    function spend(bytes32 cardId, address merchant, uint256 amt, bytes32 receipt) external;
}

interface ICrownLakalaMicropay {
    function micropayFromCard(
        address payer,
        bytes32 mercId,
        bytes32 termNo,
        bytes32 outTradeNo,
        uint256 amount,
        bytes32 receipt
    ) external;

    function payToken() external view returns (IERC20);
}

/// @title CrownLakalaCardBridge
/// @notice Wires RoyalCard NFC spend into CrownLakalaAcquiring micropay ledger.
/// @dev Flow: card owner approves bridge → bridge holds eUSD → acquiring.micropayFromCard
///      pulls from bridge. Optional RoyalCard.spend for daily-limit accounting.
///      Crown-original — not a Lakala patent fork.
contract CrownLakalaCardBridge is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IRoyalCardSpend public royalCard;
    ICrownLakalaMicropay public acquiring;
    bool public requireRoyalSpend;

    event Wired(address royalCard, address acquiring, bool requireRoyalSpend);
    event CardMicropaid(
        bytes32 indexed cardId,
        bytes32 indexed mercId,
        bytes32 indexed outTradeNo,
        address payer,
        uint256 amount,
        bytes32 receipt
    );

    error Bad();
    error Wire();

    constructor(address owner_) Ownable(owner_) {}

    function wire(address royalCard_, address acquiring_, bool requireRoyalSpend_) external onlyOwner {
        if (royalCard_ == address(0) || acquiring_ == address(0)) revert Bad();
        royalCard = IRoyalCardSpend(royalCard_);
        acquiring = ICrownLakalaMicropay(acquiring_);
        requireRoyalSpend = requireRoyalSpend_;
        emit Wired(royalCard_, acquiring_, requireRoyalSpend_);
    }

    /// @notice Card holder: NFC cosign off-chain → on-chain micropay into acquiring.
    /// @dev Acquiring must setModules(..., royalCard = this bridge, ...).
    function payWithCard(
        bytes32 cardId,
        bytes32 mercId,
        bytes32 termNo,
        bytes32 outTradeNo,
        uint256 amount,
        bytes32 receipt
    ) external nonReentrant {
        if (address(acquiring) == address(0)) revert Wire();
        if (amount == 0) revert Bad();

        IERC20 token = acquiring.payToken();

        if (requireRoyalSpend) {
            // RoyalCard enforces daily limit; merchant = this bridge
            royalCard.spend(cardId, address(this), amount, receipt);
        } else {
            token.safeTransferFrom(msg.sender, address(this), amount);
        }

        token.safeApprove(address(acquiring), 0);
        token.safeApprove(address(acquiring), amount);
        acquiring.micropayFromCard(msg.sender, mercId, termNo, outTradeNo, amount, receipt);
        emit CardMicropaid(cardId, mercId, outTradeNo, msg.sender, amount, receipt);
    }
}
