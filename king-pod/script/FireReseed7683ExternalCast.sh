#!/usr/bin/env bash
# Reseed 7683 for EXTERNAL fill only. Do NOT flash-fill.
set -euo pipefail
export PATH="$HOME/.foundry/bin:$PATH"
RPC="${BASE_RPC_URL:-https://mainnet.base.org}"
PK="${PRIVATE_KEY:?set PRIVATE_KEY}"
HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
EUSD=0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a
FILL=0x4C021c77633e9441be218d2A27a4B40c1Bd720Ab
MAX_USDC_IN=4500000000000
ORDER_EUSD=5000000000000000000000000
GAS=500000

send() {
  echo ">>> $1"
  cast send "$2" "$3" "${@:4}" --rpc-url "$RPC" --private-key "$PK" --gas-limit "$GAS"
  sleep 2
}

echo "=== approve + seed fill buffer 5M eUSD ==="
send "approve Fill" "$EUSD" "approve(address,uint256)" "$FILL" "$ORDER_EUSD"
send "seedFillBuffer" "$FILL" "seedFillBuffer(uint256)" "$ORDER_EUSD"

DEADLINE=$(($(date +%s) + 604800))
echo "=== openOrder 5M eUSD @ \$4.5M (EXTERNAL solvers — no self flash) ==="
send "openOrder" "$FILL" "openOrder(address,uint256,uint256,uint32)" "$HOT" "$ORDER_EUSD" "$MAX_USDC_IN" "$DEADLINE"
echo DONE
