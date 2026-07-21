#!/usr/bin/env bash
# Capture RSS77 OR BRETT idle >= TARGET → borrow to Landing (Steakhouse capture playbook)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

RPC="${BASE_RPC:-${RPC_URL:-https://mainnet.base.org}}"
MORPHO=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
RSS77=0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794
BRETT_M=0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16
LANDING=0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357
USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
TARGET="${TARGET_USDC:-500000000000}"
SLEEP_SECS="${SLEEP_SECS:-120}"
AUTO_FIRE="${AUTO_FIRE:-0}"  # default dry — King sets AUTO_FIRE=1

idle_usdc() {
  local mkt="$1"
  mapfile -t lines < <(cast call "$MORPHO" \
    "market(bytes32)(uint128,uint128,uint128,uint128,uint128,uint128)" \
    "$mkt" --rpc-url "$RPC")
  python3 -c "sup=int('${lines[0]}'.split()[0]); bor=int('${lines[2]}'.split()[0]); print(sup-bor if sup>bor else 0)"
}

echo "=== DUAL CAPTURE (RSS77 + BRETT) ==="
python3 -c "print(f'target=\${int(\"$TARGET\")/1e6:,.0f} auto_fire=$AUTO_FIRE')"

while true; do
  ir=$(idle_usdc "$RSS77")
  ib=$(idle_usdc "$BRETT_M")
  land=$(cast call $USDC "balanceOf(address)(uint256)" $LANDING --rpc-url $RPC | awk '{print $1}')
  python3 -c "print(f'idleRSS77=\${int(\"$ir\")/1e6:,.2f} idleBRETT=\${int(\"$ib\")/1e6:,.2f} landing=\${int(\"$land\")/1e6:,.2f}')"

  if python3 -c "import sys; sys.exit(0 if int('$land') >= int('$TARGET') else 1)"; then
    echo "Landing >= target — standing down"
    exit 0
  fi

  if python3 -c "import sys; sys.exit(0 if int('$ir') >= int('$TARGET') else 1)"; then
    echo "RSS77 CAPTURE READY"
    if [[ "$AUTO_FIRE" == "1" ]]; then
      KING_GO=1 FIRE_P1=1 BORROW_USDC="$TARGET" forge script script/FirePhase1FiveHundred.s.sol \
        --rpc-url "$RPC" --broadcast --slow -vv && exit 0
    fi
  fi

  if python3 -c "import sys; sys.exit(0 if int('$ib') >= int('$TARGET') else 1)"; then
    echo "BRETT CAPTURE READY — use FireFinishBrett or cash-leg on BRETT market"
  fi

  sleep "$SLEEP_SECS"
done
