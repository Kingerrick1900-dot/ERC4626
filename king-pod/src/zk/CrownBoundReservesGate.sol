// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, Ownable} from "../lib/Core.sol";
import {Groth16Verifier} from "./Groth16Verifier.sol";
import {ProofVecGuard} from "./ProofVecGuard.sol";

/// @notice Reserves gate with on-chain USDC balanceOf binding — no free witness.
/// @dev Two honest paths:
///      1) submitBoundProof — Groth16 + IERC20(usdc).balanceOf(subject) >= threshold
///      2) attestLive — authorized attestor only, same balanceOf check (flash path)
///      Legacy free-witness submitProof is intentionally absent.
contract CrownBoundReservesGate is Ownable {
    Groth16Verifier public immutable verifier;
    IERC20 public immutable usdc;
    uint256 public minThreshold = 700_000e6;
    uint256 public proofTtl = 7 days;

    struct Attestation {
        uint256 threshold;
        uint256 provenAt;
        bool valid;
    }

    mapping(address => Attestation) public attestations;
    mapping(address => bool) public attestor;

    event Proven(address indexed subject, uint256 threshold, uint256 provenAt, bytes32 indexed mode);
    event MinThreshold(uint256 minThreshold);
    event Ttl(uint256 proofTtl);
    event AttestorSet(address indexed who, bool allowed);
    event SilentFailureFlag(address indexed subject, bytes32 indexed code, uint256 threshold);

    error BadProof();
    error BadThreshold();
    error BadSubject();
    error Expired();
    error NotAttestor();
    error BalanceShort();

    constructor(address verifier_, address usdc_, address owner_) Ownable(owner_) {
        verifier = Groth16Verifier(verifier_);
        usdc = IERC20(usdc_);
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

    function setAttestor(address who, bool allowed) external onlyOwner {
        attestor[who] = allowed;
        emit AttestorSet(who, allowed);
    }

    /// @notice ZK + live balanceOf(subject) ≥ threshold. Public: [ok, threshold, subject].
    function submitBoundProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[3] calldata publicSignals
    ) external {
        _submitBound(a, b, c, publicSignals);
    }

    function submitBoundProofVec(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[] calldata publicSignals
    ) external {
        uint256[3] memory pub = ProofVecGuard.decodeReservesPublic(publicSignals);
        _submitBound(a, b, c, pub);
    }

    /// @notice Flash/authorized path: balanceOf(subject) ≥ threshold at call time. No ZK witness.
    function attestLive(address subject, uint256 threshold) external {
        if (!attestor[msg.sender]) revert NotAttestor();
        if (subject == address(0)) revert BadSubject();
        ProofVecGuard.requireThresholdBound(threshold, minThreshold);
        if (usdc.balanceOf(subject) < threshold) revert BalanceShort();

        attestations[subject] = Attestation({threshold: threshold, provenAt: block.timestamp, valid: true});
        emit Proven(subject, threshold, block.timestamp, bytes32("LIVE_BAL"));
    }

    function _submitBound(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[3] memory publicSignals
    ) internal {
        ProofVecGuard.requireFields3(publicSignals);
        if (publicSignals[0] != 1) revert BadProof();
        ProofVecGuard.requireThresholdBound(publicSignals[1], minThreshold);
        address subject = ProofVecGuard.requireAddressSubject(publicSignals[2]);

        // On-chain truth: free private usdcBalance witness cannot pass without live holdings.
        if (usdc.balanceOf(subject) < publicSignals[1]) revert BalanceShort();

        uint256[3] memory pub = publicSignals;
        bool ok = verifier.verifyProof(a, b, c, pub);
        if (!ok) revert BadProof();

        attestations[subject] =
            Attestation({threshold: publicSignals[1], provenAt: block.timestamp, valid: true});
        emit Proven(subject, publicSignals[1], block.timestamp, bytes32("ZK_BOUND"));
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

    function checkSilentFailure(address subject) external view returns (bool healthy, bytes32 code) {
        Attestation memory a = attestations[subject];
        if (!a.valid) return (true, bytes32(0));
        if (a.threshold < minThreshold) return (false, bytes32("THRESH_LOW"));
        if (a.provenAt > block.timestamp) return (false, bytes32("FUTURE_TS"));
        if (proofTtl > 0 && block.timestamp > a.provenAt + proofTtl) return (false, bytes32("STALE_VALID"));
        // Proven but subject no longer holds threshold — flag for alerters (attestation still TTL-valid).
        if (usdc.balanceOf(subject) < a.threshold) return (false, bytes32("BAL_DROPPED"));
        return (true, bytes32(0));
    }

    function revoke(address subject) external onlyOwner {
        delete attestations[subject];
    }
}
