// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, SafeTransfer, Ownable, ReentrancyGuard} from "./core/Core.sol";

/// @notice Base leg of Base↔Scroll eUSD link. Lock Base eUSD for Scroll mint.
/// @dev King releases Scroll mint off-chain / via Scroll link after lock event.
contract CrownBaseEusdLink is Ownable, ReentrancyGuard {
    using SafeTransfer for IERC20;

    IERC20 public immutable eusd; // Base eUSD 18dp
    address public immutable landing;

    uint256 public totalLocked;
    mapping(address => uint256) public lockedOf;
    uint256 public nonce;

    event Locked(address indexed from, address indexed scrollTo, uint256 amt, uint256 indexed lockId);
    event Unlocked(address indexed to, uint256 amt, uint256 indexed lockId);
    event Released(uint256 indexed lockId, bytes32 scrollTx);

    error BadAmt();
    error BadLock();

    struct Lock {
        address from;
        address scrollTo;
        uint256 amt;
        bool open;
        bool released;
    }

    mapping(uint256 => Lock) public locks;

    constructor(address eusd_, address landing_, address owner_) Ownable(owner_) {
        eusd = IERC20(eusd_);
        landing = landing_;
    }

    /// @notice Lock Base eUSD to be minted as Scroll eUSD to `scrollTo`.
    function lockForScroll(uint256 amt, address scrollTo) external nonReentrant returns (uint256 lockId) {
        if (amt == 0 || scrollTo == address(0)) revert BadAmt();
        eusd.safeTransferFrom(msg.sender, address(this), amt);
        lockId = ++nonce;
        locks[lockId] =
            Lock({from: msg.sender, scrollTo: scrollTo, amt: amt, open: true, released: false});
        lockedOf[msg.sender] += amt;
        totalLocked += amt;
        emit Locked(msg.sender, scrollTo, amt, lockId);
    }

    /// @notice King marks Scroll mint complete (attestation pointer).
    function markReleased(uint256 lockId, bytes32 scrollTx) external onlyOwner {
        Lock storage L = locks[lockId];
        if (!L.open || L.released) revert BadLock();
        L.released = true;
        emit Released(lockId, scrollTx);
    }

    /// @notice Reverse: unlock Base eUSD after Scroll burn (king-gated).
    function unlock(uint256 lockId, address to) external onlyOwner nonReentrant {
        Lock storage L = locks[lockId];
        if (!L.open) revert BadLock();
        L.open = false;
        uint256 amt = L.amt;
        lockedOf[L.from] -= amt;
        totalLocked -= amt;
        if (to == address(0)) to = L.from;
        eusd.safeTransfer(to, amt);
        emit Unlocked(to, amt, lockId);
    }
}
