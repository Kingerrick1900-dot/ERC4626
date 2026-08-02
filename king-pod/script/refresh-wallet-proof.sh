#!/usr/bin/env bash
# Scale the proof: re-prove from LIVE hot balances as capital grows, submit to Base gate.
# Usage: GATE=0xFfC9... bash scripts/refresh-wallet-proof.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GATE="${GATE:-0xFfC9dE1fC86d45fdB2b4163122d89F8FBfB8f579}"
export PATH="$HOME/.foundry/bin:/usr/local/bin:$PATH"
test -n "${PRIVATE_KEY:-}" || { set -a; source /tmp/king_deploy.env; set +a; }

cd "$ROOT/zk"
BASE_RPC="${BASE_RPC:-https://1rpc.io/base}" bash scripts/prove-wallet.sh

python3 - <<PY
import json, os, subprocess
p=json.load(open("proofs/wallet_proof_solidity.json"))
a,b,c,pub=p["a"],p["b"],p["c"],p["publicSignals"]
gate=os.environ.get("GATE","0xFfC9dE1fC86d45fdB2b4163122d89F8FBfB8f579")
rpc=os.environ.get("BASE_RPC") or "https://1rpc.io/base"
args=["cast","send",gate,
  "submitProof(uint256[2],uint256[2][2],uint256[2],uint256[4])",
  f"[{a[0]},{a[1]}]",
  f"[[{b[0][0]},{b[0][1]}],[{b[1][0]},{b[1][1]}]]",
  f"[{c[0]},{c[1]}]",
  f"[{pub[0]},{pub[1]},{pub[2]},{pub[3]}]",
  "--rpc-url",rpc,"--private-key",os.environ["PRIVATE_KEY"],"--json"]
raw=subprocess.check_output(args,text=True)
d=json.loads(raw)
print("refresh tx", d.get("transactionHash"), "status", d.get("status"))
print("commitment", pub[1])
print("threshold", pub[2])
print("PROOF_SCALED")
PY
