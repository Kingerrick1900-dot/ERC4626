#!/usr/bin/env bash
# Disarm draw router — stop armed draws while credit has no idle or debt is uncollateralized by cash.
set -euo pipefail
export PATH="$HOME/.foundry/bin:$PATH"
RPC="${BASE_RPC_URL:-https://mainnet.base.org}"
PK="${PRIVATE_KEY:?set PRIVATE_KEY}"

ROUTER=0xA4E04b3160c7ed3cF1c4341DD2f67a06eFF85b6c
CREDIT=0xc184A1d2486a24FAb9eB51764c9CF193AE3e6D15
HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
COLL=0x99bE1Ec7Dba573da84cF42663B60A27108B6c3e8

echo "=== BEFORE ==="
echo "router armed:" $(cast call "$ROUTER" "armed()(bool)" --rpc-url "$RPC")
echo "credit idle:" $(cast call "$CREDIT" "freeUsdc()(uint256)" --rpc-url "$RPC")
echo "credit debt:" $(cast call "$CREDIT" "debtOf(address)(uint256)" "$HOT" --rpc-url "$RPC")
echo "reserved debt:" $(cast call "$COLL" "reservedDebtUsd6()(uint256)" --rpc-url "$RPC")

echo ">>> setArmed(false)"
cast send "$ROUTER" "setArmed(bool)" false --rpc-url "$RPC" --private-key "$PK" --gas-limit 200000

echo "=== AFTER ==="
echo "router armed:" $(cast call "$ROUTER" "armed()(bool)" --rpc-url "$RPC")
echo DONE
