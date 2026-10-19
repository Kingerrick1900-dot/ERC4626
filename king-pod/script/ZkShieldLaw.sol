// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Vm} from "forge-std/Vm.sol";

interface IZkShieldGate {
    function isProven(address subject) external view returns (bool);
}

interface IZkBorders {
    function bordersSecure() external view returns (bool);
}

/// @notice Kingdom fire law: ZK_SHIELD=1 · bordersSecure · WalletGate isProven(subject).
/// @dev Quantum protection — every fire script must call before broadcast.
library ZkShieldLaw {
    address constant ZK_WALLET_GATE = 0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091;
    address constant BASE_ATTEST = 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7;
    address constant SAFE = 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0;

    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @notice Full law for a signing subject (HOT / Landing / Safe).
    function requireFire(address subject) internal view {
        require(vm.envOr("ZK_SHIELD", uint256(0)) == 1, "ZK_SHIELD");
        require(IZkBorders(BASE_ATTEST).bordersSecure(), "BORDERS");
        require(IZkShieldGate(ZK_WALLET_GATE).isProven(subject), "NOT_PROVEN_SUBJECT");
        require(IZkShieldGate(ZK_WALLET_GATE).isProven(SAFE), "NOT_PROVEN_SAFE");
    }

    /// @notice King-custody path: subject may be unproven if onBehalf/King Safe is proven.
    function requireKingCustody(address subjectOrZero) internal view {
        require(vm.envOr("ZK_SHIELD", uint256(0)) == 1, "ZK_SHIELD");
        require(IZkBorders(BASE_ATTEST).bordersSecure(), "BORDERS");
        require(IZkShieldGate(ZK_WALLET_GATE).isProven(SAFE), "NOT_PROVEN_SAFE");
        if (subjectOrZero != address(0) && subjectOrZero != SAFE) {
            // Prefer subject proven; allow Safe-proven custody if TRANSPARENT_OK is not set.
            // Law: subject MUST be proven unless KING_CUSTODY_OK=1 (Safe already proven).
            if (vm.envOr("KING_CUSTODY_OK", uint256(0)) != 1) {
                require(IZkShieldGate(ZK_WALLET_GATE).isProven(subjectOrZero), "NOT_PROVEN_SUBJECT");
            }
        }
    }
}
