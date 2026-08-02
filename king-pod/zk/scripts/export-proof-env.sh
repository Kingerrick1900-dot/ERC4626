#!/usr/bin/env bash
# Load proofs/proof_solidity.json → export env for FireZkSubmitProof
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JSON="${1:-$ROOT/proofs/proof_solidity.json}"
python3 - <<PY
import json, pathlib
p = json.loads(pathlib.Path("$JSON").read_text())
a, b, c, pub = p["a"], p["b"], p["c"], p["publicSignals"]
print(f'export PROOF_A0={a[0]}')
print(f'export PROOF_A1={a[1]}')
print(f'export PROOF_B00={b[0][0]}')
print(f'export PROOF_B01={b[0][1]}')
print(f'export PROOF_B10={b[1][0]}')
print(f'export PROOF_B11={b[1][1]}')
print(f'export PROOF_C0={c[0]}')
print(f'export PROOF_C1={c[1]}')
print(f'export PUB_OK={pub[0]}')
print(f'export PUB_THRESHOLD={pub[1]}')
print(f'export PUB_SUBJECT={pub[2]}')
PY
