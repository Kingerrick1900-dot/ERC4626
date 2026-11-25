// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "../lib/Core.sol";

interface IPayAdapter {
    function payFrom(address from, address merchant, uint256 amount, bytes32 invoiceId) external;
    function merchant(address) external view returns (bool);
}

interface IBorders {
    function bordersSecure() external view returns (bool);
}

/// @title CrownRoyalCardNFC
/// @notice Offline-cache *class* for Royal Card taps — commit receipt offline, settle online.
/// @dev Crown-original. NOT a Lakala (or any) patent fork. Seed never on-chain.
contract CrownRoyalCardNFC is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable eusd;
    address public payAdapter;
    address public attest;
    address public settler; // KAR / SoftPOS settler

    struct Cache {
        address cardOwner;
        address merchant;
        uint256 amount;
        bytes32 receipt; // NFC cosign hash
        uint64 expires;
        uint8 status; // 0 none, 1 cached, 2 settled, 3 expired/canceled
    }

    mapping(bytes32 => Cache) public caches; // cacheId
    mapping(address => uint256) public pendingDebit; // cardOwner liability

    event Cached(bytes32 indexed cacheId, address indexed cardOwner, address merchant, uint256 amount, uint64 expires);
    event Settled(bytes32 indexed cacheId, address indexed merchant, uint256 amount);
    event Canceled(bytes32 indexed cacheId);
    event ModulesSet(address payAdapter, address attest, address settler);

    error Auth();
    error Bad();
    error Borders();
    error Exists();
    error Status();

    modifier onlySettler() {
        if (msg.sender != settler && msg.sender != owner) revert Auth();
        _;
    }

    constructor(address eusd_, address owner_) Ownable(owner_) {
        require(eusd_ != address(0), "ZERO");
        eusd = IERC20(eusd_);
    }

    function setModules(address payAdapter_, address attest_, address settler_) external onlyOwner {
        payAdapter = payAdapter_;
        attest = attest_;
        settler = settler_;
        emit ModulesSet(payAdapter_, attest_, settler_);
    }

    /// @notice SoftPOS/KAR posts an offline tap for later settle (cache window).
    function cacheTap(
        bytes32 cacheId,
        address cardOwner,
        address merchant,
        uint256 amount,
        bytes32 receipt,
        uint64 ttlSec
    ) external onlySettler {
        if (cacheId == bytes32(0) || cardOwner == address(0) || merchant == address(0) || amount == 0) revert Bad();
        if (caches[cacheId].status != 0) revert Exists();
        if (payAdapter != address(0) && !IPayAdapter(payAdapter).merchant(merchant)) revert Bad();
        uint64 exp = uint64(block.timestamp + (ttlSec == 0 ? 1 days : ttlSec));
        caches[cacheId] = Cache({
            cardOwner: cardOwner,
            merchant: merchant,
            amount: amount,
            receipt: receipt,
            expires: exp,
            status: 1
        });
        pendingDebit[cardOwner] += amount;
        emit Cached(cacheId, cardOwner, merchant, amount, exp);
    }

    /// @notice Online settle — pull eUSD via PayAdapter.payFrom (adapter must allow this as puller)
    ///         or direct transferFrom if no adapter.
    function settle(bytes32 cacheId) external nonReentrant onlySettler {
        if (attest != address(0) && !IBorders(attest).bordersSecure()) revert Borders();
        Cache storage c = caches[cacheId];
        if (c.status != 1) revert Status();
        if (block.timestamp > c.expires) {
            c.status = 3;
            pendingDebit[c.cardOwner] -= c.amount;
            revert Status();
        }
        c.status = 2;
        pendingDebit[c.cardOwner] -= c.amount;

        if (payAdapter != address(0)) {
            IPayAdapter(payAdapter).payFrom(c.cardOwner, c.merchant, c.amount, cacheId);
        } else {
            eusd.safeTransferFrom(c.cardOwner, c.merchant, c.amount);
        }
        emit Settled(cacheId, c.merchant, c.amount);
    }

    function cancel(bytes32 cacheId) external onlySettler {
        Cache storage c = caches[cacheId];
        if (c.status != 1) revert Status();
        c.status = 3;
        pendingDebit[c.cardOwner] -= c.amount;
        emit Canceled(cacheId);
    }
}
