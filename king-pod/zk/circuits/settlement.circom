pragma circom 2.1.9;

include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/bitify.circom";

/// @notice Settlement fill attestation for ERC-7683 / ERC-7540 rails.
/// @dev Proves private solver USDC liquidity ≥ public minUsdc, bound to orderId + filler.
///      Does NOT modify 7540/7683 contracts — solvers attest here, then call live settler/vault.
///      Private: liquidity (USDC 6dp), salt.
///      Public: orderId (bytes32 as field), minUsdc, subject (filler address).
///      Outputs: ok, commitment=Poseidon(liquidity, salt, orderId).
template SettlementFill(n) {
    signal input liquidity;
    signal input salt;
    signal input orderId;
    signal input minUsdc;
    signal input subject;

    signal output ok;
    signal output commitment;

    component h = Poseidon(3);
    h.inputs[0] <== liquidity;
    h.inputs[1] <== salt;
    h.inputs[2] <== orderId;
    commitment <== h.out;

    component liqBits = Num2Bits(n);
    liqBits.in <== liquidity;
    component minBits = Num2Bits(n);
    minBits.in <== minUsdc;
    component subjectBits = Num2Bits(160);
    subjectBits.in <== subject;
    // orderId is a field element (bytes32 mod snark scalar); bind bit-width for DCE resistance
    component orderBits = Num2Bits(254);
    orderBits.in <== orderId;

    component gte = GreaterEqThan(n);
    gte.in[0] <== liquidity;
    gte.in[1] <== minUsdc;
    ok <== gte.out;
    ok * (ok - 1) === 0;

    signal subjectLin;
    subjectLin <== subject;
    subjectLin === subject;
}

component main {public [orderId, minUsdc, subject]} = SettlementFill(80);
