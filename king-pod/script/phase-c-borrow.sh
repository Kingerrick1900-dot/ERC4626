#!/usr/bin/env bash
# Phase C — borrow idle USDC against King LP; skim 12% to team (defaults to King).
# Requires: idle USDC in sUSDC vault > 0 (external lenders deposit first).
set -euo pipefail

RPC="${BASE_RPC:-https://base.publicnode.com}"
PK="${PRIVATE_KEY:?}"
MARKET="${MARKET:-0x50a61ca6b06563f1a44f7f2186a325b5301e2578}"
SUSDC="${SUSDC:-0x4af86ac17eb6f12588b2f3b70969f304933d1021}"
USDC="${USDC:-0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913}"
KING="${KING:-0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1}"
TEAM="${TEAM:-$KING}"
AMOUNT="${1:?usage: phase-c-borrow.sh <usdc_amount_raw_6dec>}"

IDLE=$(cast call "$USDC" "balanceOf(address)(uint256)" "$SUSDC" --rpc-url "$RPC")
MAX=$(cast call "$MARKET" "maxBorrow(address)(uint256)" "$KING" --rpc-url "$RPC")
echo "idle=$IDLE maxBorrow=$MAX amount=$AMOUNT"

python3 - << PY
idle=int("$IDLE")
maxn=int("$MAX")
amt=int("$AMOUNT")
assert amt > 0 and amt <= idle and amt <= maxn, (amt, idle, maxn)
print("ok")
PY

cast send "$MARKET" "borrow(uint256)" "$AMOUNT" \
  --rpc-url "$RPC" --private-key "$PK" --gas-price 20000000 --priority-gas-price 1000000

TEAM_AMT=$(python3 -c "print(int($AMOUNT)*12//100)")
KING_AMT=$(python3 -c "print(int($AMOUNT)-int($TEAM_AMT))")
echo "team=$TEAM_AMT king=$KING_AMT"
if [[ "$TEAM" != "$KING" && "$TEAM_AMT" != "0" ]]; then
  cast send "$USDC" "transfer(address,uint256)" "$TEAM" "$TEAM_AMT" \
    --rpc-url "$RPC" --private-key "$PK" --gas-price 20000000 --priority-gas-price 1000000
fi
echo "Phase C done. Remaining USDC stays with King wallet."
