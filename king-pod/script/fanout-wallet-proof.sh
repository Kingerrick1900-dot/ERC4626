#!/usr/bin/env bash
# Fan-out the SAME wallet-bind Groth16 proof to gates on multiple chains.
# Requires GATE_<CHAIN> env addresses where Groth16WalletVerifier+CrownZkWalletGate are deployed
# with the SAME verification key as Base wallet_reserves.
#
# Usage:
#   PROOF=zk/proofs/wallet_proof_solidity.json \
#   GATE_BASE=0xFfC9... GATE_OP=0x... GATE_ARB=0x... \
#   bash scripts/fanout-wallet-proof.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROOF="${PROOF:-$ROOT/zk/proofs/wallet_proof_solidity.json}"
HOT="${HOT:-0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1}"
export PATH="$HOME/.foundry/bin:$PATH"
test -n "${PRIVATE_KEY:-}" || { set -a; source /tmp/king_deploy.env; set +a; }

python3 - <<'PY'
import json, os, subprocess
proof=json.load(open(os.environ.get("PROOF","zk/proofs/wallet_proof_solidity.json")))
a,b,c,pub=proof["a"],proof["b"],proof["c"],proof["publicSignals"]
assert pub[0]==1
chains=[]
for name,env,rpc in [
  ("base","GATE_BASE", os.environ.get("BASE_RPC") or "https://mainnet.base.org"),
  ("optimism","GATE_OP", os.environ.get("OP_RPC") or "https://mainnet.optimism.io"),
  ("arbitrum","GATE_ARB", os.environ.get("ARB_RPC") or "https://arb1.arbitrum.io/rpc"),
  ("ethereum","GATE_ETH", os.environ.get("ETH_RPC") or "https://eth.llamarpc.com"),
]:
  gate=os.environ.get(env)
  if gate:
    chains.append((name,gate,rpc))
if not chains:
  # default: Base only
  g=os.environ.get("GATE_BASE") or "0xFfC9dE1fC86d45fdB2b4163122d89F8FBfB8f579"
  chains=[("base", g, os.environ.get("BASE_RPC") or "https://mainnet.base.org")]

for name,gate,rpc in chains:
  print(f"== submit {name} gate={gate} ==")
  # skip if already proven
  try:
    out=subprocess.check_output(["cast","call",gate,"isProven(address)(bool)",os.environ.get("HOT","0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1"),"--rpc-url",rpc],text=True)
    if out.strip().startswith("true"):
      print(f"  already proven on {name}")
      continue
  except Exception as e:
    print(f"  gate unreachable on {name}: {e}")
    continue
  args=["cast","send",gate,
    "submitProof(uint256[2],uint256[2][2],uint256[2],uint256[4])",
    f"[{a[0]},{a[1]}]",
    f"[[{b[0][0]},{b[0][1]}],[{b[1][0]},{b[1][1]}]]",
    f"[{c[0]},{c[1]}]",
    f"[{pub[0]},{pub[1]},{pub[2]},{pub[3]}]",
    "--rpc-url",rpc,"--private-key",os.environ["PRIVATE_KEY"],"--json"]
  try:
    raw=subprocess.check_output(args,text=True)
    d=json.loads(raw)
    print("  tx", d.get("transactionHash"), "status", d.get("status"))
  except subprocess.CalledProcessError as e:
    print("  FAIL", e)
print("FANOUT_DONE")
PY
