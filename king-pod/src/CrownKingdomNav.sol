// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "./lib/Core.sol";

interface IYrssAssets {
    function totalAssets() external view returns (uint256); // USDC 6dp for yRSS
}

interface IERC20Bal {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface IAmericaCapacity {
    function mintCapacity() external view returns (uint256);
    function unlockedCapacity() external view returns (uint256);
    function minted() external view returns (uint256);
}

/// @title CrownKingdomNav
/// @notice Public NAV: Locked gold + Idle eUSD + Minted + Capacity. ZK root for ZkAttest.
/// @dev Treats King billions as real — reads chain balances, no fantasy.
contract CrownKingdomNav is Ownable {
    IYrssAssets public immutable yrss;
    IERC20Bal public immutable eusd;
    address public immutable idleWallet; // Landing / SpendVault idle surface
    IAmericaCapacity public capacity;
    address public attest;

    struct Nav {
        uint256 lockedGoldUsd6; // yRSS totalAssets
        uint256 idleEusd18; // idle wallet eUSD (REAL billions)
        uint256 mintedEusd18; // eUSD totalSupply (REAL)
        uint256 capacityEusd18; // America ceiling
        uint256 unlockedEusd18; // unlocked tranche headroom max
        uint64 updatedAt;
        bytes32 root;
    }

    Nav public latest;

    event NavPublished(
        uint256 lockedGoldUsd6,
        uint256 idleEusd18,
        uint256 mintedEusd18,
        uint256 capacityEusd18,
        uint256 unlockedEusd18,
        bytes32 root
    );
    event ModulesSet(address capacity, address attest);

    constructor(address yrss_, address eusd_, address idleWallet_, address owner_) Ownable(owner_) {
        require(yrss_ != address(0) && eusd_ != address(0) && idleWallet_ != address(0), "ZERO");
        yrss = IYrssAssets(yrss_);
        eusd = IERC20Bal(eusd_);
        idleWallet = idleWallet_;
    }

    function setModules(address capacity_, address attest_) external onlyOwner {
        capacity = IAmericaCapacity(capacity_);
        attest = attest_;
        emit ModulesSet(capacity_, attest_);
    }

    /// @notice Snapshot on-chain truth into NAV + ZK root.
    function publish() external onlyOwner returns (bytes32 root) {
        uint256 locked = yrss.totalAssets();
        uint256 idle = eusd.balanceOf(idleWallet);
        uint256 minted_ = eusd.totalSupply();
        uint256 cap = address(capacity) == address(0) ? 0 : capacity.mintCapacity();
        uint256 unlocked = address(capacity) == address(0) ? 0 : capacity.unlockedCapacity();

        root = keccak256(
            abi.encode(
                block.chainid,
                address(yrss),
                address(eusd),
                idleWallet,
                locked,
                idle,
                minted_,
                cap,
                unlocked,
                block.timestamp
            )
        );

        latest = Nav({
            lockedGoldUsd6: locked,
            idleEusd18: idle,
            mintedEusd18: minted_,
            capacityEusd18: cap,
            unlockedEusd18: unlocked,
            updatedAt: uint64(block.timestamp),
            root: root
        });

        emit NavPublished(locked, idle, minted_, cap, unlocked, root);
    }
}
