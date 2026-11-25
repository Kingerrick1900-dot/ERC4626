#!/usr/bin/env bash
# Prove Elepan@$1 ≥ $700k from LIVE hot Elepan balance via wallet_reserves circuit.
# Maps Elepan 8dp → rss_equiv = elepan * 1e10 so floor(rss/1e12) = floor(elepan/100) = $ 6dp.
# Usage: THRESHOLD=700000000000 ./scripts/prove-elepan.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
BUILD="$ROOT/build"
OUT="$ROOT/proofs"
mkdir -p "$OUT"

RPC="${BASE_RPC:-${RPC_URL:-https://mainnet.base.org}}"
HOT="${SUBJECT:-0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1}"
ELEPAN="${ELEPAN:-0x50639C42E2FFDEC4F68FB468968a55b3Af944583}"
THRESHOLD="${THRESHOLD:-700000000000}"
SALT="${SALT:-$(python3 -c 'import secrets; print(int.from_bytes(secrets.token_bytes(16),"big"))')}"

export PATH="$HOME/.foundry/bin:/usr/local/bin:$PATH"

ELEPAN_BAL=$(cast call "$ELEPAN" 'balanceOf(address)(uint256)' "$HOT" --rpc-url "$RPC" | awk '{print $1}')

SUBJECT_DEC=$(python3 - <<PY
print(int("${HOT}", 16))
PY
)

python3 - <<PY
elepan=int("${ELEPAN_BAL}")
thr=int("${THRESHOLD}")
# 8dp → 18dp equiv for \$1 marking in wallet_reserves
rss = elepan * 10**10
rss_val = rss // 10**12  # == elepan // 100
kusd = 0
total = kusd + rss_val
print(f"LIVE elepan={elepan} rss_equiv={rss}")
print(f"elepanValue_6dp={rss_val} total_6dp={total} threshold={thr}")
assert total >= thr, f"Elepan value {total} < threshold {thr} — refuse free witness"
print("ELEPAN_BIND_OK live wallet covers threshold")
open("proofs/_elepan_rss_equiv.txt","w").write(str(rss))
PY

RSS_EQUIV=$(cat "$OUT/_elepan_rss_equiv.txt")
INPUT="$OUT/elepan_input.json"
cat > "$INPUT" <<EOF
{
  "kusd": "0",
  "rss": "$RSS_EQUIV",
  "salt": "$SALT",
  "threshold": "$THRESHOLD",
  "subject": "$SUBJECT_DEC"
}
EOF

echo "== witness (live Elepan → rss_equiv) =="
node "$BUILD/wallet_reserves_js/generate_witness.js" \
  "$BUILD/wallet_reserves_js/wallet_reserves.wasm" "$INPUT" "$OUT/elepan_witness.wtns"

echo "== prove =="
npx snarkjs groth16 prove "$BUILD/wallet_reserves_final.zkey" "$OUT/elepan_witness.wtns" \
  "$OUT/elepan_proof.json" "$OUT/elepan_public.json"

echo "== verify local =="
npx snarkjs groth16 verify "$BUILD/wallet_reserves_vkey.json" "$OUT/elepan_public.json" "$OUT/elepan_proof.json"

python3 - <<'PY'
import json, pathlib
root = pathlib.Path("proofs")
proof = json.loads((root/"elepan_proof.json").read_text())
pub = json.loads((root/"elepan_public.json").read_text())
out = {
  "a": [int(proof["pi_a"][0]), int(proof["pi_a"][1])],
  "b": [[int(proof["pi_b"][0][1]), int(proof["pi_b"][0][0])],
        [int(proof["pi_b"][1][1]), int(proof["pi_b"][1][0])]],
  "c": [int(proof["pi_c"][0]), int(proof["pi_c"][1])],
  "publicSignals": [int(x) for x in pub],
}
(root/"elepan_proof_solidity.json").write_text(json.dumps(out, indent=2))
print("wrote proofs/elepan_proof_solidity.json")
print("publicSignals [ok, commitment, threshold, subject] =", out["publicSignals"])
assert out["publicSignals"][0] == 1, "ok != 1"
PY

echo "ELEPAN_PROOF_OK"
