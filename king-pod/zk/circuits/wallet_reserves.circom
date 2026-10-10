pragma circom 2.1.9;

include "../node_modules/circomlib/circuits/comparators.circom";
include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/bitify.circom";

/// @notice BIND wallet capital: prove kUSD + RSS@\$1 ≥ threshold; sizes private; commitment public.
/// @dev Private: kusd (6dp), rss (wei), salt.
///      Public outputs/inputs: ok, commitment=Poseidon(kusd,rss,salt), threshold, subject.
///      RSS @ \$1: value_6dp += floor(rss / 1e12).
template WalletReservesGte(n) {
    signal input kusd;
    signal input rss;
    signal input salt;
    signal input threshold;
    signal input subject;

    signal output ok;
    signal output commitment;

    component h = Poseidon(3);
    h.inputs[0] <== kusd;
    h.inputs[1] <== rss;
    h.inputs[2] <== salt;
    commitment <== h.out;

    var ONE_E12 = 1000000000000;

    signal rssValue;
    signal rem;
    rssValue <-- rss \ ONE_E12;
    rem <-- rss - rssValue * ONE_E12;
    rss === rssValue * ONE_E12 + rem;

    component remBits = Num2Bits(40);
    remBits.in <== rem;
    component remLt = LessThan(40);
    remLt.in[0] <== rem;
    remLt.in[1] <== ONE_E12;
    remLt.out === 1;

    component rssValBits = Num2Bits(n);
    rssValBits.in <== rssValue;
    component kusdBits = Num2Bits(n);
    kusdBits.in <== kusd;

    signal total;
    total <== kusd + rssValue;

    component gte = GreaterEqThan(n);
    gte.in[0] <== total;
    gte.in[1] <== threshold;
    ok <== gte.out;

    signal subjectSq;
    subjectSq <== subject * subject;
}

component main {public [threshold, subject]} = WalletReservesGte(80);
