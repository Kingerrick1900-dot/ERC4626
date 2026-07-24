// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Bounds-checked decoding for externally supplied proof / public-signal vectors.
/// @dev gnark-crypto / Aztec-class bug: never allocate or iterate from an attacker-chosen length
///      without an upper bound. Fixed-size calldata arrays are preferred; dynamic paths use MAX_*.
library ProofVecGuard {
    /// @dev BN254 scalar field (same as snarkJS / Groth16WalletVerifier `r`).
    uint256 internal constant SNARK_SCALAR_FIELD =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;

    /// @dev Hard cap on public signals (wallet-bind uses 4; reserves uses 3).
    uint256 internal constant MAX_PUBLIC_SIGNALS = 8;
    /// @dev Sanity cap on attested USDC-raw threshold (1e15 * 1e6).
    uint256 internal constant MAX_THRESHOLD = 1_000_000_000_000_000e6;

    error BadLen();
    error BadField();
    error BadSubjectBits();
    error BadThresholdBound();

    function requireField(uint256 v) internal pure {
        if (v >= SNARK_SCALAR_FIELD) revert BadField();
    }

    function requireFields(uint256[4] memory v) internal pure {
        requireField(v[0]);
        requireField(v[1]);
        requireField(v[2]);
        requireField(v[3]);
    }

    function requireFields3(uint256[3] memory v) internal pure {
        requireField(v[0]);
        requireField(v[1]);
        requireField(v[2]);
    }

    /// @notice Decode dynamic publicSignals with length + field bounds (never trust raw length alone).
    function decodeWalletPublic(uint256[] calldata raw) internal pure returns (uint256[4] memory out) {
        uint256 n = raw.length;
        // Allocate against validated upper limit, not attacker length beyond cap.
        if (n != 4 || n > MAX_PUBLIC_SIGNALS) revert BadLen();
        out[0] = raw[0];
        out[1] = raw[1];
        out[2] = raw[2];
        out[3] = raw[3];
        requireFields(out);
    }

    function decodeReservesPublic(uint256[] calldata raw) internal pure returns (uint256[3] memory out) {
        uint256 n = raw.length;
        if (n != 3 || n > MAX_PUBLIC_SIGNALS) revert BadLen();
        out[0] = raw[0];
        out[1] = raw[1];
        out[2] = raw[2];
        requireFields3(out);
    }

    /// @notice Subject must fit in 160 bits — reject high-bit smuggling in publicSignals.
    function requireAddressSubject(uint256 subjectRaw) internal pure returns (address subject) {
        if (subjectRaw > type(uint160).max) revert BadSubjectBits();
        subject = address(uint160(subjectRaw));
        if (subject == address(0)) revert BadSubjectBits();
    }

    function requireThresholdBound(uint256 threshold, uint256 minThreshold) internal pure {
        if (threshold < minThreshold || threshold > MAX_THRESHOLD) revert BadThresholdBound();
    }
}
