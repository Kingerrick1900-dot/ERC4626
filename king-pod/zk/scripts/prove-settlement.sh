#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p proofs

# Args: liquidity_usdc6  orderId_hex  minUsdc6  subject_hex  [salt]
LIQ="${1:?liquidity}"
OID_HEX="${2:?orderId hex}"
MIN="${3:?minUsdc}"
SUBJ_HEX="${4:?subject}"
SALT="${5:-$((RANDOM * RANDOM))}"

# Field-reduce orderId
OID=$(python3 - <<PY
r=21888242871839275222246405745257275088548364400416034343698204186575808495617
oid=int("${OID_HEX}".replace("0x",""),16)
print(oid % r)
PY
)
SUBJ=$(python3 - <<PY
print(int("${SUBJ_HEX}".replace("0x",""),16))
PY
)

cat > proofs/settlement_input.json <<EOF
{"liquidity":"$LIQ","salt":"$SALT","orderId":"$OID","minUsdc":"$MIN","subject":"$SUBJ"}
EOF

echo "[prove] witness"
node build/settlement_js/generate_witness.js build/settlement_js/settlement.wasm proofs/settlement_input.json proofs/settlement_witness.wtns

echo "[prove] groth16"
npx snarkjs groth16 prove build/settlement_final.zkey proofs/settlement_witness.wtns proofs/settlement_proof.json proofs/settlement_public.json

echo "[prove] solidity calldata"
npx snarkjs zkey export soliditycalldata proofs/settlement_public.json proofs/settlement_proof.json > proofs/settlement_calldata.txt
npx snarkjs groth16 export-solidity-calldata proofs/settlement_public.json proofs/settlement_proof.json > proofs/settlement_calldata.txt 2>/dev/null || true

python3 - <<'PY'
import json
from pathlib import Path
proof=json.loads(Path("proofs/settlement_proof.json").read_text())
pub=json.loads(Path("proofs/settlement_public.json").read_text())
out={
  "a":[proof["pi_a"][0],proof["pi_a"][1]],
  "b":[[proof["pi_b"][0][1],proof["pi_b"][0][0]],[proof["pi_b"][1][1],proof["pi_b"][1][0]]],
  "c":[proof["pi_c"][0],proof["pi_c"][1]],
  "publicSignals":pub
}
Path("proofs/settlement_proof_solidity.json").write_text(json.dumps(out,indent=2))
print("wrote proofs/settlement_proof_solidity.json")
print("publicSignals", pub)
PY

echo "SETTLEMENT_PROVE_OK"
