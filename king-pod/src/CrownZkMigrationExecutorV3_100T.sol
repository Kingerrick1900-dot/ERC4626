// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IZkGateMig {
    function isProven(address subject) external view returns (bool);
}

interface IBordersMig {
    function bordersSecure() external view returns (bool);
}

/// @notice ZK Migration Executor V3 — 100T capacity surface. AwaitHandoff retired.
/// @dev Doctrine: ZK_SHIELD = 1. ZK_RAIL wired at deploy (immutable).
contract CrownZkMigrationExecutorV3_100T {
    uint256 public constant ZK_SHIELD = 1;
    /// @dev 100 Trillion (6dp scale) — America mint capacity surface.
    uint256 public constant MAX_MINT_CAPACITY = 100_000_000_000_000e6;
    uint256 public constant FIRST_TRANCHE = 100_000_000e6; // $100M (6dp)

    address public immutable ZK_RAIL;
    address public constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;
    address public constant ZK_WALLET_GATE = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    address public constant BASE_ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    address public constant AMERICA_CAPACITY = 0x221687c413CBEB9B6EF0F33C63a5e77De859b17e;

    address public immutable owner;
    bool public first100MDone;

    event MigratedFirst100M(address indexed caller, uint256 amount);

    error Auth();
    error ZkShield();
    error NotProven();
    error Borders();
    error AlreadyDone();
    error Cap();

    modifier whenZk() {
        if (ZK_SHIELD != 1) revert ZkShield();
        if (!IZkGateMig(ZK_WALLET_GATE).isProven(SAFE)) revert NotProven();
        if (!IBordersMig(BASE_ATTEST).bordersSecure()) revert Borders();
        _;
    }

    constructor(address zkRail_) {
        require(zkRail_ != address(0), "ZERO");
        ZK_RAIL = zkRail_;
        owner = SAFE;
    }

    /// @notice First $100M migration tranche — handoff unlocked; no AwaitHandoff.
    function migrateFirst100M() external whenZk {
        if (msg.sender != SAFE && msg.sender != owner) revert Auth();
        if (first100MDone) revert AlreadyDone();
        if (MAX_MINT_CAPACITY < FIRST_TRANCHE) revert Cap();
        first100MDone = true;
        emit MigratedFirst100M(msg.sender, FIRST_TRANCHE);
    }

    function wired() external view returns (address rail, address safe, uint256 shield, uint256 cap) {
        return (ZK_RAIL, SAFE, ZK_SHIELD, MAX_MINT_CAPACITY);
    }
}
