#!/usr/bin/env bash
# Phase-2 Recycler Loop — repay $9M into PARK, withdraw yRSS idle, feed treasury.
# FREEZE GATE: refuses unless kingdom USDC ≥ $9M. Requires HOT_KEY (= Base hot).
set -euo pipefail
export PATH="${HOME}/.foundry/bin:${PATH}"

RPC="${BASE_RPC_URL:-https://mainnet.base.org}"
if echo "$RPC" | grep -qi polygon; then RPC="https://mainnet.base.org"; fi

HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
MORPHO=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
YRSS=0xF80C0529bD94C773844E459853CD91B9263dD525
TREASURY=0xA1215D21eBC646F609d2CcAAc0cD4E00bF0ebd97
CREDIT=0x5568fE662363d7F3fa52349A99C9e19C6616B60d
PARK_ID=0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88

# PARK market params (live idToMarketParams)
LOAN=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
COLLAT=0x7a305D07B537359cf468eAea9bb176E5308bC337
ORACLE=0xB5840644142B341a6145335e2ebc82EEBC7aE1B9
IRM=0x46415998764C29aB2a25CbeA6254146D50D22687
LLTV=770000000000000000

NEED=9000000000000 # $9M * 1e6
AMT="${RECYCLE_USDC_AMT:-$NEED}"

PK="${HOT_KEY:-${BASE_HOT_KEY:-}}"
if [[ -z "${PK}" ]]; then
  echo "FAIL: set HOT_KEY (Base hot 0x6708…)"
  exit 1
fi
[[ "$PK" == 0x* ]] || PK="0x$PK"
DERIVED=$(cast wallet address --private-key "$PK")
if [[ "${DERIVED,,}" != "${HOT,,}" ]]; then
  echo "FAIL: key → $DERIVED want HOT $HOT"
  exit 1
fi

hot_usdc=$(cast call "$USDC" "balanceOf(address)(uint256)" "$HOT" --rpc-url "$RPC" | awk '{print $1}')
credit_usdc=$(cast call "$CREDIT" "freeUsdc()(uint256)" --rpc-url "$RPC" | awk '{print $1}')
echo "HOT USDC=$hot_usdc  credit.freeUsdc=$credit_usdc  need=$AMT"

# Gate: HOT must hold the sweep cash (credit idle alone cannot Morpho.repay from HOT)
python3 - "$hot_usdc" "$AMT" <<'PY'
import sys
have, need = int(sys.argv[1]), int(sys.argv[2])
if have < need:
    print(f"GATE FAIL: HOT USDC {have/1e6:.2f} < need {need/1e6:.2f}")
    print("FREEZE holds — source $9M USDC first (see FREEZE-PHASE2-RECYCLER-LOOP.md)")
    sys.exit(2)
print(f"GATE OK: {have/1e6:.2f} USDC on HOT")
PY

echo "=== BEFORE PARK ==="
cast call "$MORPHO" "market(bytes32)((uint128,uint128,uint128,uint128,uint128,uint128))" "$PARK_ID" --rpc-url "$RPC"
echo -n "yRSS maxWithdraw="; cast call "$YRSS" "maxWithdraw(address)(uint256)" "$HOT" --rpc-url "$RPC"

echo ">>> 1) approve Morpho USDC"
cast send "$USDC" "approve(address,uint256)" "$MORPHO" "$AMT" \
  --private-key "$PK" --rpc-url "$RPC" --gas-limit 80000

echo ">>> 2) Morpho.repay $AMT into PARK on behalf HOT"
# repay(MarketParams, assets, shares, onBehalf, data)
cast send "$MORPHO" \
  "repay((address,address,address,address,uint256),uint256,uint256,address,bytes)" \
  "($LOAN,$COLLAT,$ORACLE,$IRM,$LLTV)" \
  "$AMT" 0 "$HOT" 0x \
  --private-key "$PK" --rpc-url "$RPC" --gas-limit 500000

echo "=== AFTER REPAY ==="
cast call "$MORPHO" "market(bytes32)((uint128,uint128,uint128,uint128,uint128,uint128))" "$PARK_ID" --rpc-url "$RPC"
MAX_W=$(cast call "$YRSS" "maxWithdraw(address)(uint256)" "$HOT" --rpc-url "$RPC" | awk '{print $1}')
echo "yRSS maxWithdraw=$MAX_W"

WITHDRAW="$AMT"
# withdraw min(AMT, maxWithdraw)
WITHDRAW=$(python3 -c "print(min(int('$AMT'), int('$MAX_W')))")
if [[ "$WITHDRAW" -le 0 ]]; then
  echo "FAIL: maxWithdraw=0 after repay — abort before treasury"
  exit 3
fi

echo ">>> 3) yRSS.withdraw $WITHDRAW → HOT"
cast send "$YRSS" "withdraw(uint256,address,address)" "$WITHDRAW" "$HOT" "$HOT" \
  --private-key "$PK" --rpc-url "$RPC" --gas-limit 800000

echo ">>> 4) approve + treasury.sweep"
cast send "$USDC" "approve(address,uint256)" "$TREASURY" "$WITHDRAW" \
  --private-key "$PK" --rpc-url "$RPC" --gas-limit 80000
cast send "$TREASURY" "sweep(uint256)" "$WITHDRAW" \
  --private-key "$PK" --rpc-url "$RPC" --gas-limit 300000

echo "=== AFTER ==="
echo -n "HOT USDC="; cast call "$USDC" "balanceOf(address)(uint256)" "$HOT" --rpc-url "$RPC"
echo -n "treasury surplus="; cast call "$TREASURY" "surplus()(uint256)" --rpc-url "$RPC"
echo -n "credit freeUsdc="; cast call "$CREDIT" "freeUsdc()(uint256)" --rpc-url "$RPC"
echo DONE — rotate HOT only after King confirms ledger
