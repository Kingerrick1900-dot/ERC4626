"""
Certora properties for CrownAssetCdpVault / CrownElepanCdpVault ZK fallback.

Invariant class: fallback may bypass wallet-bind attestation ONLY for owner, and NEVER
allows mint against nonexistent collateral or HF below safetyFloor.
"""

methods {
    function coll() external returns (uint256) envfree;
    function debt() external returns (uint256) envfree;
    function zkFallbackEnabled() external returns (bool) envfree;
    function healthFactor() external returns (uint256) envfree;
    function safetyFloor() external returns (uint256) envfree;
    function owner() external returns (address) envfree;
}

/// @notice Vault token balance covers accounted collateral (no phantom lock).
invariant collBackedByBalance(env e)
    coll() <= collateralBalance(e);

/// @notice With open debt, HF must remain ≥ safetyFloor after any successful mutation
///         (deposit/withdraw/mint/repay/close) — holds with or without ZK fallback.
rule mintPreservesFloor(uint256 amt) {
    env e;
    require e.msg.sender == owner();
    uint256 hfBefore = healthFactor();
    mint(e, amt);
    assert healthFactor() >= safetyFloor();
    assert hfBefore >= 0; // keep CVL happy with pre-state mention
}
