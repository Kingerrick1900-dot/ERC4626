// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "../lib/Core.sol";
import {Groth16WalletVerifier} from "./Groth16WalletVerifier.sol";
import {ProofVecGuard} from "./ProofVecGuard.sol";

/// @notice ZK wallet-bind gate — prove kUSD+RSS@$1 ≥ threshold with Poseidon commitment.
/// @dev Public signals: [ok, commitment, threshold, subject]. Exact sizes stay private.
///      Hardened: field/subject/threshold bounds + silent-failure monitors + dynamic vec guard.
contract CrownZkWalletGate is Ownable {
    using ProofVecGuard for uint256[];

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
    /// @notice Proactive monitor: proof accepted but attestation state looks inconsistent.
    event SilentFailureFlag(address indexed subject, bytes32 indexed code, uint256 commitment, uint256 threshold);

    error BadProof();
    error BadThreshold();
    error BadSubject();
    error Expired();

    constructor(address verifier_, address owner_) Ownable(owner_) {
        verifier = Groth16WalletVerifier(verifier_);
    }

    function setMinThreshold(uint256 t) external onlyOwner {
        if (t == 0 || t > ProofVecGuard.MAX_THRESHOLD) revert BadThreshold();
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
        _submit(a, b, c, publicSignals);
    }

    /// @notice Dynamic-array entrypoint with length + field bounds (gnark-length allocation class).
    function submitProofVec(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[] calldata publicSignals
    ) external {
        uint256[4] memory pub = ProofVecGuard.decodeWalletPublic(publicSignals);
        _submit(a, b, c, pub);
    }

    function _submit(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[4] memory publicSignals
    ) internal {
        ProofVecGuard.requireFields(publicSignals);
        if (publicSignals[0] != 1) revert BadProof();
        ProofVecGuard.requireThresholdBound(publicSignals[2], minThreshold);
        address subject = ProofVecGuard.requireAddressSubject(publicSignals[3]);

        uint256[4] memory pub = publicSignals;
        bool ok = verifier.verifyProof(a, b, c, pub);
        if (!ok) revert BadProof();

        // Under-constrained / silent-fail monitors (on-chain flags for off-chain alerters).
        if (publicSignals[1] == 0) {
            emit SilentFailureFlag(subject, bytes32("ZERO_COMMIT"), 0, publicSignals[2]);
        }

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

    /// @notice Proactive integrity check — ZK bugs often do not revert txs; flag inconsistency.
    /// @dev Returns (healthy, code). Non-zero code ⇒ monitor should alert.
    function checkSilentFailure(address subject) external view returns (bool healthy, bytes32 code) {
        Attestation memory a = _att[subject];
        if (!a.valid) return (true, bytes32(0));
        if (a.threshold < minThreshold) return (false, bytes32("THRESH_LOW"));
        if (a.threshold > ProofVecGuard.MAX_THRESHOLD) return (false, bytes32("THRESH_HIGH"));
        if (a.commitment == 0) return (false, bytes32("ZERO_COMMIT"));
        if (a.provenAt > block.timestamp) return (false, bytes32("FUTURE_TS"));
        if (proofTtl > 0 && block.timestamp > a.provenAt + proofTtl) {
            // Stale but still marked valid in storage — silent expiry class
            return (false, bytes32("STALE_VALID"));
        }
        return (true, bytes32(0));
    }

    /// @notice Owner can invalidate a subject attestation (circuit compromise response).
    function revoke(address subject) external onlyOwner {
        delete _att[subject];
    }
}
