#!/usr/bin/env bash
# Phase I — arm HuntRouter (requires HOT_KEY). Does NOT invent bot fleet.
set -euo pipefail
export PATH="${HOME}/.foundry/bin:${PATH}"
RPC="${BASE_RPC_URL:-https://mainnet.base.org}"
if echo "$RPC" | grep -qi polygon; then RPC="https://mainnet.base.org"; fi

HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
HUNT=0xc4c63f8CD4182452f665e338F87b4d31aeF04516
PK="${HOT_KEY:-${BASE_HOT_KEY:-}}"
[[ -n "$PK" ]] || { echo "FAIL: set HOT_KEY"; exit 1; }
[[ "$PK" == 0x* ]] || PK="0x$PK"
DERIVED=$(cast wallet address --private-key "$PK")
[[ "${DERIVED,,}" == "${HOT,,}" ]] || { echo "FAIL: not HOT"; exit 1; }

echo "kill before: $(cast call "$HUNT" "killSwitch()(bool)" --rpc-url "$RPC")"

echo ">>> setGasSafe HOT"
cast send "$HUNT" "setGasSafe(address)" "$HOT" --private-key "$PK" --rpc-url "$RPC" --gas-limit 80000

echo ">>> setHunter HOT true"
cast send "$HUNT" "setHunter(address,bool)" "$HOT" true --private-key "$PK" --rpc-url "$RPC" --gas-limit 80000

# Optional extra hunters: HUNT_EOAS="0xabc,0xdef"
if [[ -n "${HUNT_EOAS:-}" ]]; then
  IFS=',' read -ra HS <<<"$HUNT_EOAS"
  for h in "${HS[@]}"; do
    h=$(echo "$h" | tr -d ' ')
    [[ -n "$h" ]] || continue
    echo ">>> setHunter $h"
    cast send "$HUNT" "setHunter(address,bool)" "$h" true --private-key "$PK" --rpc-url "$RPC" --gas-limit 80000
  done
fi

echo ">>> setKillSwitch false (ARM)"
cast send "$HUNT" "setKillSwitch(bool)" false --private-key "$PK" --rpc-url "$RPC" --gas-limit 80000

echo "kill after: $(cast call "$HUNT" "killSwitch()(bool)" --rpc-url "$RPC")"
echo "hunter HOT: $(cast call "$HUNT" "hunter(address)(bool)" "$HOT" --rpc-url "$RPC")"
echo DONE — register targets before live hunt(); tips must meet minTipWei
