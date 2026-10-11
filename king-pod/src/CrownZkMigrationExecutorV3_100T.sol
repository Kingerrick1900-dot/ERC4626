// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IZkGateMig {
    function isProven(address subject) external view returns (bool);
}

interface IBordersMig {
    function bordersSecure() external view returns (bool);
}

/// @notice ZK Migration Executor V3 — 100T capacity surface. migrateFirst100M gated; not auto-fired.
/// @dev Registry: ZK_RAIL + SAFE wired. Doctrine: ZK_SHIELD = 1.
contract CrownZkMigrationExecutorV3_100T {
    uint256 public constant ZK_SHIELD = 1;
    /// @dev 100 Trillion (6dp scale) — America mint capacity surface.
    uint256 public constant MAX_MINT_CAPACITY = 100_000_000_000_000e6;
    uint256 public constant FIRST_TRANCHE = 100_000_000e6; // $100M (6dp)

    address public constant ZK_RAIL = 0xa787C47E04b38bcD84ceAd05ce903B0005E9Dda3;
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
    error AwaitHandoff();

    modifier whenZk() {
        if (ZK_SHIELD != 1) revert ZkShield();
        if (!IZkGateMig(ZK_WALLET_GATE).isProven(SAFE)) revert NotProven();
        if (!IBordersMig(BASE_ATTEST).bordersSecure()) revert Borders();
        _;
    }

    constructor() {
        owner = SAFE;
    }

    /// @notice First $100M migration tranche — exists on-chain; fire only on next King handoff.
    function migrateFirst100M() external whenZk {
        if (msg.sender != SAFE && msg.sender != owner) revert Auth();
        if (first100MDone) revert AlreadyDone();
        // Capacity check surface — does not mint until King unlocks America tranche.
        if (MAX_MINT_CAPACITY < FIRST_TRANCHE) revert AwaitHandoff();
        revert AwaitHandoff();
    }

    function wired() external pure returns (address rail, address safe, uint256 shield, uint256 cap) {
        return (ZK_RAIL, SAFE, ZK_SHIELD, MAX_MINT_CAPACITY);
    }
}
