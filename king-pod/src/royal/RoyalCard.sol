// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";

interface IBorders {
    function bordersSecure() external view returns (bool);
}

/// @title RoyalCard
/// @notice Kingdom NFC spend rail — card id ↔ spend vault allowance (Phase-4 preview).
/// @dev Original Crown design for physical cosign + eUSD merchant pay.
///      Not a fork of any third-party payment patent. Hardware cosign is off-chain (KAR NFC).
contract RoyalCard is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable eusd;
    address public spendVault; // CrownSpendVault or PayAdapter
    address public attest; // optional CrownZkAttest — borders gate

    struct Card {
        address owner; // wallet bound to physical card pubkey
        bytes32 pubKeyHash; // NFC secp256k1 pubkey hash (seed never on-chain)
        uint256 dailyLimit; // eUSD 18dp
        uint256 spentToday;
        uint64 dayStart;
        bool active;
        bool frozen;
    }

    mapping(bytes32 => Card) public cards; // cardId => Card
    mapping(address => bytes32) public primaryCard; // wallet => cardId

    event CardIssued(bytes32 indexed cardId, address indexed owner, bytes32 pubKeyHash, uint256 dailyLimit);
    event CardFrozen(bytes32 indexed cardId, bool frozen);
    event CardLimit(bytes32 indexed cardId, uint256 dailyLimit);
    event Spent(bytes32 indexed cardId, address indexed merchant, uint256 amt, bytes32 receipt);
    event ModulesSet(address spendVault, address attest);

    error BadCard();
    error FrozenErr();
    error Limit();
    error Borders();
    error BadAmt();

    constructor(address eusd_, address owner_) Ownable(owner_) {
        require(eusd_ != address(0), "ZERO");
        eusd = IERC20(eusd_);
    }

    function setModules(address spendVault_, address attest_) external onlyOwner {
        spendVault = spendVault_;
        attest = attest_;
        emit ModulesSet(spendVault_, attest_);
    }

    /// @notice Issue a logical card bound to an owner wallet + NFC pubkey hash.
    function issue(bytes32 cardId, address owner_, bytes32 pubKeyHash, uint256 dailyLimit)
        external
        onlyOwner
    {
        if (cardId == bytes32(0) || owner_ == address(0) || pubKeyHash == bytes32(0)) revert BadCard();
        Card storage c = cards[cardId];
        require(c.owner == address(0), "EXISTS");
        c.owner = owner_;
        c.pubKeyHash = pubKeyHash;
        c.dailyLimit = dailyLimit;
        c.dayStart = uint64(block.timestamp / 1 days);
        c.active = true;
        primaryCard[owner_] = cardId;
        emit CardIssued(cardId, owner_, pubKeyHash, dailyLimit);
    }

    function setFrozen(bytes32 cardId, bool on) external onlyOwner {
        cards[cardId].frozen = on;
        emit CardFrozen(cardId, on);
    }

    function setDailyLimit(bytes32 cardId, uint256 dailyLimit) external onlyOwner {
        cards[cardId].dailyLimit = dailyLimit;
        emit CardLimit(cardId, dailyLimit);
    }

    /// @notice Owner-authorized spend toward merchant (NFC cosign enforced off-chain by KAR).
    /// @dev On-chain: borders + daily limit + pull eUSD from owner to merchant/vault.
    function spend(bytes32 cardId, address merchant, uint256 amt, bytes32 receipt) external nonReentrant {
        Card storage c = cards[cardId];
        if (!c.active || c.owner != msg.sender) revert BadCard();
        if (c.frozen) revert FrozenErr();
        if (amt == 0 || merchant == address(0)) revert BadAmt();
        if (attest != address(0) && !IBorders(attest).bordersSecure()) revert Borders();

        uint64 day = uint64(block.timestamp / 1 days);
        if (day != c.dayStart) {
            c.dayStart = day;
            c.spentToday = 0;
        }
        if (c.spentToday + amt > c.dailyLimit) revert Limit();
        c.spentToday += amt;

        // Pull from card owner → merchant (PayAdapter may wrap later)
        eusd.safeTransferFrom(msg.sender, merchant, amt);
        emit Spent(cardId, merchant, amt, receipt);
    }
}
