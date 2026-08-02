pragma circom 2.1.9;

include "../node_modules/circomlib/circuits/comparators.circom";

/// @notice Prove private USDC balance (6dp raw) ≥ public threshold, bound to subject.
/// @dev Public: threshold, subject (uint160 address as field). Private: usdcBalance.
template ReservesGte(n) {
    signal input usdcBalance;
    signal input threshold;
    signal input subject;
    signal output ok;

    component gte = GreaterEqThan(n);
    gte.in[0] <== usdcBalance;
    gte.in[1] <== threshold;
    ok <== gte.out;

    // Bind subject into the constraint system (public input must be constrained).
    signal subjectSq;
    subjectSq <== subject * subject;
}

// 64 bits covers USDC raw well past $1e12.
component main {public [threshold, subject]} = ReservesGte(64);
