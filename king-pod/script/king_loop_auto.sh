#!/usr/bin/env bash
# King loop auto-engine — no manual restarts.
# Keys via env; loop key may also live at /tmp/loop_pk.txt (never commit).
set -euo pipefail
cd "$(dirname "$0")/.."

export MAX_LOOPS="${MAX_LOOPS:-50}"
export MIN_USDC="${MIN_USDC:-100000}"
export HARD_GAS_CAP="${HARD_GAS_CAP:-350000}"
export AUTO_RESTART="${AUTO_RESTART:-1}"
export RESTART_SLEEP="${RESTART_SLEEP:-45}"

# Prefer private send RPC if provided; else leave pick_rpc() to demote public Base.
if [[ -z "${LOOP_SEND_RPC:-}" && -f /tmp/loop_rpc.txt ]]; then
  export LOOP_SEND_RPC="$(tr -d '[:space:]' </tmp/loop_rpc.txt)"
fi

if [[ -z "${LOOP_PRIVATE_KEY:-}" && -f /tmp/loop_pk.txt ]]; then
  export LOOP_PRIVATE_KEY="$(tr -d '[:space:]' </tmp/loop_pk.txt)"
fi

exec python3 -u script/king_loop.py
