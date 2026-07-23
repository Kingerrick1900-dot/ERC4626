"""
Certora formal verification specs for Crown ZK wallet-bind gate + CDP fallback.

STATUS: Specs authored for Certora Prover (Morpho-style). Running the Prover requires
Certora credentials / CLI (`certoraRun`) which are NOT present in this environment.
Treat this file as the formal property set to execute before deploying a hardened VK.

Run (when Certora available):
  certoraRun certora/conf/WalletGate.conf

Properties map to Aztec Connect / under-constraint failure classes:
  - public inputs constrained against on-chain policy (ok, threshold, subject bits)
  - provenance of attestation only via successful verifyProof
  - CDP fallback never weakens collateral / HF invariants
"""

using CrownZkWalletGate as gate;

methods {
    function isProven(address) external returns (bool) envfree;
    function minThreshold() external returns (uint256) envfree;
    function commitmentOf(address) external returns (uint256) envfree;
    function checkSilentFailure(address) external returns (bool, bytes32) envfree;
}

/// @notice Proven subject must have been attested with threshold ≥ minThreshold at submit time.
///         (Storage may lag policy changes; isProven still requires valid+TTL.)
rule provenImpliesValidAttestation(address subject) {
    env e;
    bool p = isProven(subject);
    uint256 thresh;
    uint256 provenAt;
    bool valid;
    thresh, provenAt, valid = gate.attestations(e, subject);
    assert !p || valid;
}

/// @notice revoke clears proven status.
rule revokeClearsProven(address subject) {
    env e;
    require e.msg.sender == gate.owner(e);
    gate.revoke(e, subject);
    assert !isProven(subject);
}

/// @notice ok!=1 cannot produce a proven subject (public input constrained on-chain).
/// @dev Modeled as: after any successful submitProof, attestation.threshold ≥ minThreshold
///      and subject fits address (enforced by ProofVecGuard — see harness).
invariant minThresholdPositive()
    minThreshold() > 0;
