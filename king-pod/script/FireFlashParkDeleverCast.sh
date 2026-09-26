#!/usr/bin/env bash
# Phase II — deploy + run CrownFlashParkDelever (DELEVER only · ΔUSDC≈0).
# Requires: HOT_KEY, forge, BASE_RPC. Optional: DELEVER_AMT (default 9e6*1e6)
set -euo pipefail
export PATH="${HOME}/.foundry/bin:${PATH}"
cd "$(dirname "$0")/.."

RPC="${BASE_RPC_URL:-https://mainnet.base.org}"
if echo "$RPC" | grep -qi polygon; then RPC="https://mainnet.base.org"; fi

HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
MORPHO=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
YRSS=0xF80C0529bD94C773844E459853CD91B9263dD525
USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
COLLAT=0x7a305D07B537359cf468eAea9bb176E5308bC337
ORACLE=0xB5840644142B341a6145335e2ebc82EEBC7aE1B9
IRM=0x46415998764C29aB2a25CbeA6254146D50D22687
LLTV=770000000000000000
AMT="${DELEVER_AMT:-9000000000000}"

PK="${HOT_KEY:-${BASE_HOT_KEY:-}}"
[[ -n "$PK" ]] || { echo "FAIL: set HOT_KEY"; exit 1; }
[[ "$PK" == 0x* ]] || PK="0x$PK"
DERIVED=$(cast wallet address --private-key "$PK")
[[ "${DERIVED,,}" == "${HOT,,}" ]] || { echo "FAIL: not HOT"; exit 1; }

echo "WARN: This DELEVERS debt/yRSS claim. It does NOT mint a \$375M war chest."
echo "AMT=$AMT"

echo ">>> forge create CrownFlashParkDelever"
OUT=$(forge create src/prime/CrownFlashParkDelever.sol:CrownFlashParkDelever \
  --rpc-url "$RPC" --private-key "$PK" --broadcast \
  --constructor-args "$MORPHO" "$YRSS" "$USDC" "$HOT" "$HOT" "$COLLAT" "$ORACLE" "$IRM" "$LLTV" -vvv)
echo "$OUT"
DELEVER=$(echo "$OUT" | rg -o 'Deployed to: 0x[a-fA-F0-9]{40}' | tail -1 | awk '{print $3}')
[[ -n "$DELEVER" ]] || { echo "FAIL: no deploy address"; exit 1; }
echo "DELEVER=$DELEVER"

echo ">>> yrss.approve delever"
cast send "$YRSS" "approve(address,uint256)" "$DELEVER" \
  0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff \
  --private-key "$PK" --rpc-url "$RPC" --gas-limit 100000

echo ">>> delever($AMT)"
cast send "$DELEVER" "delever(uint256)" "$AMT" \
  --private-key "$PK" --rpc-url "$RPC" --gas-limit 2000000

echo -n "yRSS maxWithdraw="; cast call "$YRSS" "maxWithdraw(address)(uint256)" "$HOT" --rpc-url "$RPC"
echo DONE
