#!/bin/bash
# Preflight + tight EIP-1559 send for Base desk ops
# Usage: gas-safe-send.sh <to> <sig> [args...]
set -euo pipefail
RPC="${RPC_URL:-https://mainnet.base.org}"
PK="${PRIVATE_KEY:?PRIVATE_KEY required}"
TO="$1"; shift
SIG="$1"; shift
FROM=$(cast wallet address --private-key "$PK")
echo "[preflight] cast call..."
if ! cast call "$TO" "$SIG" "$@" --from "$FROM" --rpc-url "$RPC" >/tmp/cast-preflight.out 2>/tmp/cast-preflight.err; then
  echo "[preflight] REVERT — no broadcast"
  cat /tmp/cast-preflight.err
  exit 1
fi
echo "[preflight] OK"
# estimate gas then pad 20%, cap tip
EST=$(cast estimate "$TO" "$SIG" "$@" --from "$FROM" --rpc-url "$RPC" 2>/dev/null || echo 500000)
LIMIT=$(( EST * 120 / 100 ))
if [ "$LIMIT" -lt 100000 ]; then LIMIT=100000; fi
if [ "$LIMIT" -gt 800000 ]; then LIMIT=800000; fi
echo "[send] gas-limit=$LIMIT tip=0.001gwei"
cast send "$TO" "$SIG" "$@" --private-key "$PK" --rpc-url "$RPC" \
  --gas-limit "$LIMIT" --priority-gas-price 0.001gwei --gas-price 0.01gwei
