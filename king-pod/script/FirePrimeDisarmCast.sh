#!/usr/bin/env bash
# Phase-1 hard lock: disarm LIVE USDCBorrowRouter (requires Base HOT key).
# Usage: HOT_KEY=0x… bash king-pod/script/FirePrimeDisarmCast.sh
set -euo pipefail
export PATH="${HOME}/.foundry/bin:${PATH}"

RPC="${BASE_RPC_URL:-https://mainnet.base.org}"
# Refuse Polygon RPC misconfig
if echo "$RPC" | grep -qi polygon; then
  RPC="https://mainnet.base.org"
fi

HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
ROUTER=0xBb3C372D4A0C398b6107f13ea4b1AB00B2b0A7aC
CREDIT=0x5568fE662363d7F3fa52349A99C9e19C6616B60d
COLL=0x99bE1Ec7Dba573da84cF42663B60A27108B6c3e8
OLD_ROUTER=0xA4E04b3160c7ed3cF1c4341DD2f67a06eFF85b6c

PK="${HOT_KEY:-${BASE_HOT_KEY:-}}"
if [[ -z "${PK}" ]]; then
  echo "FAIL: set HOT_KEY (Base hot 0x6708…) — PRIVATE_KEY in env is Scroll, not HOT"
  exit 1
fi
if [[ "$PK" != 0x* ]]; then PK="0x$PK"; fi

DERIVED=$(cast wallet address --private-key "$PK")
if [[ "${DERIVED,,}" != "${HOT,,}" ]]; then
  echo "FAIL: key derives to $DERIVED — need HOT $HOT"
  exit 1
fi

echo "=== BEFORE (chain $(cast chain-id --rpc-url "$RPC")) ==="
echo "live armed:  $(cast call "$ROUTER" "armed()(bool)" --rpc-url "$RPC")"
echo "old armed:   $(cast call "$OLD_ROUTER" "armed()(bool)" --rpc-url "$RPC")"
echo "freeUsdc:     $(cast call "$CREDIT" "freeUsdc()(uint256)" --rpc-url "$RPC")"
echo "debt HOT:    $(cast call "$CREDIT" "debtOf(address)(uint256)" "$HOT" --rpc-url "$RPC")"
echo "capacity:    $(cast call "$COLL" "borrowCapacityUsd6()(uint256)" --rpc-url "$RPC")"

ARMED=$(cast call "$ROUTER" "armed()(bool)" --rpc-url "$RPC")
if [[ "$ARMED" == "false" ]]; then
  echo "Already disarmed — nothing to send"
  exit 0
fi

echo ">>> setArmed(false) on LIVE router $ROUTER"
cast send "$ROUTER" "setArmed(bool)" false \
  --rpc-url "$RPC" --private-key "$PK" --gas-limit 80000

echo "=== AFTER ==="
echo "live armed: $(cast call "$ROUTER" "armed()(bool)" --rpc-url "$RPC")"
echo DONE
