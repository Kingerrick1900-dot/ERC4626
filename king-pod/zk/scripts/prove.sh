#!/usr/bin/env bash
# Generate Groth16 proof: USDC balance ≥ threshold for subject.
# Usage:
#   USDC_BALANCE=700000000000 THRESHOLD=700000000000 SUBJECT=0x6708... ./scripts/prove.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
BUILD="$ROOT/build"
OUT="$ROOT/proofs"
mkdir -p "$OUT"

USDC_BALANCE="${USDC_BALANCE:?set USDC_BALANCE raw 6dp}"
THRESHOLD="${THRESHOLD:-700000000000}" # $700,000
SUBJECT_HEX="${SUBJECT:-0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1}"
# field element = address as decimal
SUBJECT_DEC=$(python3 - <<PY
print(int("${SUBJECT_HEX}", 16))
PY
)

INPUT="$OUT/input.json"
cat > "$INPUT" <<EOF
{
  "usdcBalance": "$USDC_BALANCE",
  "threshold": "$THRESHOLD",
  "subject": "$SUBJECT_DEC"
}
EOF

echo "== witness =="
node "$BUILD/reserves_js/generate_witness.js" "$BUILD/reserves_js/reserves.wasm" "$INPUT" "$OUT/witness.wtns"

echo "== prove =="
npx snarkjs groth16 prove "$BUILD/reserves_final.zkey" "$OUT/witness.wtns" "$OUT/proof.json" "$OUT/public.json"

echo "== verify local =="
npx snarkjs groth16 verify "$BUILD/verification_key.json" "$OUT/public.json" "$OUT/proof.json"

echo "== solidity calldata =="
npx snarkjs zkey export soliditycalldata "$OUT/public.json" "$OUT/proof.json" | tee "$OUT/calldata.txt"

python3 - <<'PY'
import json, pathlib
root = pathlib.Path("proofs")
proof = json.loads((root/"proof.json").read_text())
pub = json.loads((root/"public.json").read_text())
out = {
  "a": [int(proof["pi_a"][0]), int(proof["pi_a"][1])],
  "b": [[int(proof["pi_b"][0][1]), int(proof["pi_b"][0][0])], [int(proof["pi_b"][1][1]), int(proof["pi_b"][1][0])]],
  "c": [int(proof["pi_c"][0]), int(proof["pi_c"][1])],
  "publicSignals": [int(x) for x in pub],
}
(root/"proof_solidity.json").write_text(json.dumps(out, indent=2))
print("wrote proofs/proof_solidity.json")
print("publicSignals", out["publicSignals"])
PY

echo "PROOF_OK"
