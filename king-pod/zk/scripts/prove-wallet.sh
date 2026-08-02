#!/usr/bin/env bash
# Prove wallet bind from LIVE hot balances (kUSD + RSS). No free witness.
# Usage: THRESHOLD=700000000000 SUBJECT=0x6708... ./scripts/prove-wallet.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
BUILD="$ROOT/build"
OUT="$ROOT/proofs"
mkdir -p "$OUT"

RPC="${BASE_RPC:-${RPC_URL:-https://1rpc.io/base}}"
HOT="${SUBJECT:-0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1}"
KUSD="${KUSD:-0x0FEA62084A024544891f03035E85401C2C886c1b}"
RSS="${RSS:-0x7a305D07B537359cf468eAea9bb176E5308bC337}"
THRESHOLD="${THRESHOLD:-700000000000}"
SALT="${SALT:-$(python3 -c 'import secrets; print(int.from_bytes(secrets.token_bytes(16),"big"))')}"

export PATH="$HOME/.foundry/bin:/usr/local/bin:$PATH"

KUSD_BAL=$(cast call "$KUSD" 'balanceOf(address)(uint256)' "$HOT" --rpc-url "$RPC" | awk '{print $1}')
RSS_BAL=$(cast call "$RSS" 'balanceOf(address)(uint256)' "$HOT" --rpc-url "$RPC" | awk '{print $1}')

SUBJECT_DEC=$(python3 - <<PY
print(int("${HOT}", 16))
PY
)

python3 - <<PY
kusd=int("${KUSD_BAL}")
rss=int("${RSS_BAL}")
thr=int("${THRESHOLD}")
rss_val = rss // 10**12
total = kusd + rss_val
print(f"LIVE kusd={kusd} rss={rss}")
print(f"rssValue_6dp={rss_val} total_6dp={total} threshold={thr}")
assert total >= thr, f"wallet value {total} < threshold {thr} — refuse free witness"
print("BIND_OK live wallet covers threshold")
PY

INPUT="$OUT/wallet_input.json"
cat > "$INPUT" <<EOF
{
  "kusd": "$KUSD_BAL",
  "rss": "$RSS_BAL",
  "salt": "$SALT",
  "threshold": "$THRESHOLD",
  "subject": "$SUBJECT_DEC"
}
EOF

echo "== witness (live balances) =="
node "$BUILD/wallet_reserves_js/generate_witness.js" \
  "$BUILD/wallet_reserves_js/wallet_reserves.wasm" "$INPUT" "$OUT/wallet_witness.wtns"

echo "== prove =="
npx snarkjs groth16 prove "$BUILD/wallet_reserves_final.zkey" "$OUT/wallet_witness.wtns" \
  "$OUT/wallet_proof.json" "$OUT/wallet_public.json"

echo "== verify local =="
npx snarkjs groth16 verify "$BUILD/wallet_reserves_vkey.json" "$OUT/wallet_public.json" "$OUT/wallet_proof.json"

python3 - <<'PY'
import json, pathlib
root = pathlib.Path("proofs")
proof = json.loads((root/"wallet_proof.json").read_text())
pub = json.loads((root/"wallet_public.json").read_text())
# order: outputs ok, commitment then public threshold, subject
out = {
  "a": [int(proof["pi_a"][0]), int(proof["pi_a"][1])],
  "b": [[int(proof["pi_b"][0][1]), int(proof["pi_b"][0][0])],
        [int(proof["pi_b"][1][1]), int(proof["pi_b"][1][0])]],
  "c": [int(proof["pi_c"][0]), int(proof["pi_c"][1])],
  "publicSignals": [int(x) for x in pub],
}
(root/"wallet_proof_solidity.json").write_text(json.dumps(out, indent=2))
print("wrote proofs/wallet_proof_solidity.json")
print("publicSignals [ok, commitment, threshold, subject] =", out["publicSignals"])
assert out["publicSignals"][0] == 1, "ok != 1"
PY

echo "WALLET_PROOF_OK"
