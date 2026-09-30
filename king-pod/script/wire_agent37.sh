#!/usr/bin/env bash
# FIRE wire — push King HOT ops env onto Agent37 Hermes instance via Hosting API exec.
# Usage: AGENT37_KEY=sk_live_... HOT_KEY=0x... BASE_RPC=... bash script/wire_agent37.sh
set -euo pipefail
: "${AGENT37_KEY:?set AGENT37_KEY}"
: "${HOT_KEY:?set HOT_KEY}"
: "${BASE_RPC:=${BASE_RPC_URL:-https://mainnet.base.org}}"
INSTANCE_ID="${INSTANCE_ID:-hs1r8hko0l}"
API="https://api.agent37.com/v1"
INST_URL="https://${INSTANCE_ID}.agent37.app"

auth=(-H "Authorization: Bearer ${AGENT37_KEY}" -H "Content-Type: application/json")
xkey=(-H "X-Agent37-Key: ${AGENT37_KEY}")

echo "== instance =="
curl -sS "${API}/instances/${INSTANCE_ID}" "${auth[@]}" | tee /tmp/a37-inst.json | head -c 2000
echo

echo "== health =="
# poll health
for i in 1 2 3 4 5 6 7 8 9 10; do
  code=$(curl -sS -o /tmp/a37-health.json -w '%{http_code}' "${INST_URL}/v1/health" "${xkey[@]}") || true
  echo "health_try=$i http=$code $(head -c 200 /tmp/a37-health.json 2>/dev/null)"
  if rg -q '"healthy"[[:space:]]*:[[:space:]]*true' /tmp/a37-health.json 2>/dev/null; then break; fi
  sleep 3
done

exec_cmd() {
  local cmd="$1"
  curl -sS -X POST "${API}/instances/${INSTANCE_ID}/exec" "${auth[@]}" \
    -d "$(python3 -c 'import json,sys; print(json.dumps({"command":sys.argv[1],"user":"root"}))' "$cmd")"
}

echo "== install foundry/cast if missing =="
exec_cmd 'command -v cast >/dev/null || (curl -L https://foundry.paradigm.xyz | bash && /root/.foundry/bin/foundryup)' | tee /tmp/a37-foundry.json | head -c 1500
echo

echo "== write env (mode 600) =="
# Build remote script that writes ~/.king/fire.env
B64=$(python3 - <<PY
import base64, os
content = f"""# KING FIRE ENV — agent37 Hermes — do not commit
HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
HOT_KEY={os.environ['HOT_KEY']}
PRIVATE_KEY={os.environ.get('PRIVATE_KEY', os.environ['HOT_KEY'])}
BASE_RPC={os.environ.get('BASE_RPC','https://mainnet.base.org')}
BASE_RPC_URL={os.environ.get('BASE_RPC','https://mainnet.base.org')}
INSTANCE_ID={os.environ.get('INSTANCE_ID','hs1r8hko0l')}
AGENT37_URL=https://hs1r8hko0l.agent37.app
USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
EUSD=0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a
RSS=0x7a305D07B537359cf468eAea9bb176E5308bC337
ELE=0x50639C42E2FFDEC4F68FB468968a55b3Af944583
ELEPAN=0x50639C42E2FFDEC4F68FB468968a55b3Af944583
ELE_DECIMALS=8
ELEPAN_ZK_GATE=0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30
CBBTC=0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf
WETH=0x4200000000000000000000000000000000000006
"""
print(base64.b64encode(content.encode()).decode())
PY
)
exec_cmd "mkdir -p /root/.king && echo ${B64} | base64 -d > /root/.king/fire.env && chmod 600 /root/.king/fire.env && ls -la /root/.king/fire.env" | tee /tmp/a37-env.json
echo

echo "== verify HOT =="
exec_cmd 'set -a; . /root/.king/fire.env; set +a; export PATH="$PATH:/root/.foundry/bin:/home/ubuntu/.foundry/bin"; cast wallet address --private-key "$HOT_KEY"; cast balance 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1 --rpc-url "$BASE_RPC"; cast call 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 "balanceOf(address)(uint256)" 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1 --rpc-url "$BASE_RPC"' | tee /tmp/a37-verify.json
echo
echo "WIRE_DONE instance=${INSTANCE_ID}"
