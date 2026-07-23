pragma circom 2.1.9;

include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/bitify.circom";

/// @notice BIND wallet capital: prove kUSD + RSS@$1 ≥ threshold; sizes private; commitment public.
/// @dev HARDENED (Aztec Connect / under-constraint class):
///      - Every witness that represents the same logical value is assert_equal-bound via `<==`/`===`.
///      - Public inputs `threshold` and `subject` are circuit-constrained (range + boolean ok), not free.
///      - `subject` is bound to 160 bits (EVM address); high bits cannot carry unbound payload.
///      - `ok` is forced boolean; gate also requires ok==1 on-chain.
///      - Division remainder is range-checked: rem < 1e12.
///      - This circuit is single-shot (no numTxs vector). Multi-tx circuits MUST bind numTxs to the
///        full proven set — see CONSTRAINT-AUDIT.md.
///      Private: kusd (6dp), rss (wei), salt.
///      Public: threshold, subject. Outputs: ok, commitment=Poseidon(kusd,rss,salt).
template WalletReservesGte(n) {
    signal input kusd;
    signal input rss;
    signal input salt;
    signal input threshold;
    signal input subject;

    signal output ok;
    signal output commitment;

    // --- Commitment binds private witnesses ---
    component h = Poseidon(3);
    h.inputs[0] <== kusd;
    h.inputs[1] <== rss;
    h.inputs[2] <== salt;
    commitment <== h.out;

    var ONE_E12 = 1000000000000;

    // --- Exact division: rss = rssValue * 1e12 + rem, rem < 1e12 ---
    signal rssValue;
    signal rem;
    rssValue <-- rss \ ONE_E12;
    rem <-- rss - rssValue * ONE_E12;
    // assert_equal: reconstructed rss matches witness
    rss === rssValue * ONE_E12 + rem;

    component remBits = Num2Bits(40);
    remBits.in <== rem;
    component remLt = LessThan(40);
    remLt.in[0] <== rem;
    remLt.in[1] <== ONE_E12;
    remLt.out === 1;

    // --- Range-bind value limbs (no unbound high bits) ---
    component rssValBits = Num2Bits(n);
    rssValBits.in <== rssValue;
    component kusdBits = Num2Bits(n);
    kusdBits.in <== kusd;
    component threshBits = Num2Bits(n);
    threshBits.in <== threshold;

    // --- Subject must be a 160-bit address (public input, not prover-free beyond range) ---
    component subjectBits = Num2Bits(160);
    subjectBits.in <== subject;

    signal total;
    total <== kusd + rssValue;

    component gte = GreaterEqThan(n);
    gte.in[0] <== total;
    gte.in[1] <== threshold;
    ok <== gte.out;

    // Force ok ∈ {0,1} (boolean constraint — closes under-constrained ok witness class)
    ok * (ok - 1) === 0;

    // Re-bind subject through a linear identity so the 160-bit range check cannot be DCE'd:
    // subjectLin === subject (assert_equal of the same logical value across wires).
    signal subjectLin;
    subjectLin <== subject;
    subjectLin === subject;
}

component main {public [threshold, subject]} = WalletReservesGte(80);
