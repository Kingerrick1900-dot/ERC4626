// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IZkGateBook {
    function isProven(address account) external view returns (bool);
    /// @dev Matches CrownZkWalletGate / CrownZkReservesGate getter: (threshold, provenAt, valid).
    function attestations(address account) external view returns (uint256 value, uint256 provenAt, bool valid);
    function minThreshold() external view returns (uint256);
}

/// @notice Shared ZK gate checks for Kingdom loan / passive / exit stack.
library ZkKingGate {
    error NotProven();
    error BelowThreshold();

    function requireProven(IZkGateBook gate, address king) internal view {
        if (!gate.isProven(king)) revert NotProven();
        (uint256 value,, bool valid) = gate.attestations(king);
        if (!valid || value < gate.minThreshold()) revert BelowThreshold();
    }

    function attestValue(IZkGateBook gate, address king) internal view returns (uint256 value) {
        (value,,) = gate.attestations(king);
    }
}
