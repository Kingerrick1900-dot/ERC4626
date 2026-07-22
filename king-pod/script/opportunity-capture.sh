#!/usr/bin/env bash
# OPPORTUNITY CAPTURE - not hope costume.
# When RSS/USDC Morpho idle >= TARGET, immediately cash-leg borrow to Landing.
# Steakhouse posture: demand is armed; capture liquidity the second it faces us.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

RPC="${BASE_RPC:-${RPC_URL:-https://mainnet.base.org}}"
MORPHO=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
MARKET=0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794
LANDING=0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357
USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
DESK=0xDbf7C4Ad01418ec1b753fa039d5e5B54aF4C065D

TARGET="${TARGET_USDC:-500000000000}"   # $500k Phase 1
SLEEP_SECS="${SLEEP_SECS:-60}"
AUTO_FIRE="${AUTO_FIRE:-1}"

idle_usdc() {
  mapfile -t lines < <(cast call "$MORPHO" \
    "market(bytes32)(uint128,uint128,uint128,uint128,uint128,uint128)" \
    "$MARKET" --rpc-url "$RPC")
  python3 -c "sup=int('${lines[0]}'.split()[0]); bor=int('${lines[2]}'.split()[0]); print(sup-bor if sup>bor else 0)"
}

echo "=== OPPORTUNITY CAPTURE ENGINE ==="
python3 -c "print(f'target=\${int(\"$TARGET\")/1e6:,.0f} auto=$AUTO_FIRE poll=${SLEEP_SECS}s')"

while true; do
  idle="$(idle_usdc)"
  land="$(cast call $USDC "balanceOf(address)(uint256)" $LANDING --rpc-url $RPC | awk '{print $1}')"
  raised="$(cast call $DESK "raisedUsdc()(uint256)" --rpc-url $RPC | awk '{print $1}')"
  python3 -c "print(f'idle=\${int(\"$idle\")/1e6:,.2f} landing=\${int(\"$land\")/1e6:,.2f} deskRaised=\${int(\"$raised\")/1e6:,.2f}')"

  if python3 -c "import sys; sys.exit(0 if int('$land') >= int('$TARGET') else 1)"; then
    echo "PHASE1 ALREADY WON on Landing - capture standing down"
    exit 0
  fi

  if python3 -c "import sys; sys.exit(0 if int('$idle') >= int('$TARGET') else 1)"; then
    echo "IDLE FACING US - CAPTURE"
    if [[ "$AUTO_FIRE" == "1" ]]; then
      [[ -n "${PRIVATE_KEY:-}" ]] || { echo "PRIVATE_KEY missing"; exit 1; }
      KING_GO=1 FIRE_P1=1 BORROW_USDC="$TARGET" \
        forge script script/FirePhase1FiveHundred.s.sol:FirePhase1FiveHundred \
        --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --broadcast --slow -vv
      echo "CAPTURE FIRED"
      exit 0
    fi
  fi
  sleep "$SLEEP_SECS"
done
