// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "../lib/Core.sol";
import {Groth16Verifier} from "./Groth16Verifier.sol";

/// @notice ZK reserves gate — verify Groth16 proof that USDC ≥ threshold for subject.
/// @dev Public signals: [ok, threshold, subject]. ok must be 1.
contract CrownZkReservesGate is Ownable {
    Groth16Verifier public immutable verifier;
    uint256 public minThreshold = 700_000e6; // $700k USDC raw
    uint256 public proofTtl = 7 days;

    struct Attestation {
        uint256 threshold;
        uint256 provenAt;
        bool valid;
    }

    mapping(address => Attestation) public attestations;

    event Proven(address indexed subject, uint256 threshold, uint256 provenAt);
    event MinThreshold(uint256 minThreshold);
    event Ttl(uint256 proofTtl);

    error BadProof();
    error BadThreshold();
    error BadSubject();
    error Expired();

    constructor(address verifier_, address owner_) Ownable(owner_) {
        verifier = Groth16Verifier(verifier_);
    }

    function setMinThreshold(uint256 t) external onlyOwner {
        if (t == 0) revert BadThreshold();
        minThreshold = t;
        emit MinThreshold(t);
    }

    function setTtl(uint256 ttl) external onlyOwner {
        proofTtl = ttl;
        emit Ttl(ttl);
    }

    /// @notice Submit Groth16 proof to Base. Binds subject address in publicSignals[2].
    function submitProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[3] calldata publicSignals
    ) external {
        // publicSignals: [ok, threshold, subject]
        if (publicSignals[0] != 1) revert BadProof();
        if (publicSignals[1] < minThreshold) revert BadThreshold();
        address subject = address(uint160(publicSignals[2]));
        if (subject == address(0)) revert BadSubject();

        uint256[3] memory pub = publicSignals;
        bool ok = verifier.verifyProof(a, b, c, pub);
        if (!ok) revert BadProof();

        attestations[subject] =
            Attestation({threshold: publicSignals[1], provenAt: block.timestamp, valid: true});
        emit Proven(subject, publicSignals[1], block.timestamp);
    }

    function isProven(address subject) public view returns (bool) {
        Attestation memory a = attestations[subject];
        if (!a.valid) return false;
        if (proofTtl > 0 && block.timestamp > a.provenAt + proofTtl) return false;
        return true;
    }

    function requireProven(address subject) external view {
        if (!isProven(subject)) revert Expired();
    }
}
