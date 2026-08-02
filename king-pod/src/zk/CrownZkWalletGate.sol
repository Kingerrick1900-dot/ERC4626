// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "../lib/Core.sol";
import {Groth16WalletVerifier} from "./Groth16WalletVerifier.sol";

/// @notice ZK wallet-bind gate — prove kUSD+RSS@\$1 ≥ threshold with Poseidon commitment.
/// @dev Public signals: [ok, commitment, threshold, subject]. Exact sizes stay private.
contract CrownZkWalletGate is Ownable {
    Groth16WalletVerifier public immutable verifier;
    uint256 public minThreshold = 700_000e6;
    uint256 public proofTtl = 7 days;

    struct Attestation {
        uint256 threshold;
        uint256 commitment;
        uint256 provenAt;
        bool valid;
    }

    mapping(address => Attestation) private _att;

    event Proven(address indexed subject, uint256 threshold, uint256 commitment, uint256 provenAt);
    event MinThreshold(uint256 minThreshold);
    event Ttl(uint256 proofTtl);

    error BadProof();
    error BadThreshold();
    error BadSubject();
    error Expired();

    constructor(address verifier_, address owner_) Ownable(owner_) {
        verifier = Groth16WalletVerifier(verifier_);
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

    /// @notice Submit Groth16 wallet-bind proof. publicSignals: [ok, commitment, threshold, subject]
    function submitProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[4] calldata publicSignals
    ) external {
        if (publicSignals[0] != 1) revert BadProof();
        if (publicSignals[2] < minThreshold) revert BadThreshold();
        address subject = address(uint160(publicSignals[3]));
        if (subject == address(0)) revert BadSubject();

        uint256[4] memory pub = publicSignals;
        bool ok = verifier.verifyProof(a, b, c, pub);
        if (!ok) revert BadProof();

        _att[subject] = Attestation({
            threshold: publicSignals[2],
            commitment: publicSignals[1],
            provenAt: block.timestamp,
            valid: true
        });
        emit Proven(subject, publicSignals[2], publicSignals[1], block.timestamp);
    }

    /// @notice Compatible with CrownZkCredit._att (threshold, provenAt, valid).
    function attestations(address subject)
        external
        view
        returns (uint256 threshold, uint256 provenAt, bool valid)
    {
        Attestation memory a = _att[subject];
        return (a.threshold, a.provenAt, a.valid);
    }

    function isProven(address subject) public view returns (bool) {
        Attestation memory a = _att[subject];
        if (!a.valid) return false;
        if (proofTtl > 0 && block.timestamp > a.provenAt + proofTtl) return false;
        return true;
    }

    function commitmentOf(address subject) external view returns (uint256) {
        return _att[subject].commitment;
    }

    function requireProven(address subject) external view {
        if (!isProven(subject)) revert Expired();
    }
}
