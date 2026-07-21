#!/usr/bin/env bash
# KING REST WATCH — polls Morpho RSS/USDC idle; fires cash-leg to Landing when ready.
# Safe: refuses below MIN_IDLE. No flash. No yRSS circle.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

RPC="${BASE_RPC:-${RPC_URL:-https://mainnet.base.org}}"
MORPHO=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
MARKET=0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794
DESK=0xDbf7C4Ad01418ec1b753fa039d5e5B54aF4C065D
LANDING=0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357
USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913

BORROW_USDC="${BORROW_USDC:-700000000000}"   # $700k default (desk ceiling)
MIN_IDLE="${MIN_IDLE:-$BORROW_USDC}"
SLEEP_SECS="${SLEEP_SECS:-180}"
AUTO_FIRE="${AUTO_FIRE:-0}"                 # 1 = broadcast when idle OK

idle_usdc() {
  # Six separate returns — first token of lines 1 and 3 (supply, borrow)
  mapfile -t lines < <(cast call "$MORPHO" \
    "market(bytes32)(uint128,uint128,uint128,uint128,uint128,uint128)" \
    "$MARKET" --rpc-url "$RPC")
  python3 -c "sup=int('${lines[0]}'.split()[0]); bor=int('${lines[2]}'.split()[0]); print(sup-bor if sup>bor else 0)"
}

desk_status() {
  local sale live raised land
  sale="$(cast call "$DESK" "rssForSale()(uint256)" --rpc-url "$RPC" | awk '{print $1}')"
  live="$(cast call "$DESK" "live()(bool)" --rpc-url "$RPC")"
  raised="$(cast call "$DESK" "raisedUsdc()(uint256)" --rpc-url "$RPC" | awk '{print $1}')"
  land="$(cast call "$USDC" "balanceOf(address)(uint256)" "$LANDING" --rpc-url "$RPC" | awk '{print $1}')"
  python3 -c "sale=int('$sale'); raised=int('$raised'); land=int('$land'); print(f'desk live=$live rssForSale={sale/1e18:.0f} raisedUsdc=\${raised/1e6:,.2f} landingUsdc=\${land/1e6:,.2f}')"
}

echo "=== KING REST WATCH ==="
python3 -c "print(f'borrow=\${int(\"$BORROW_USDC\")/1e6:,.0f} minIdle=\${int(\"$MIN_IDLE\")/1e6:,.0f} auto=$AUTO_FIRE every ${SLEEP_SECS}s')"
desk_status

while true; do
  idle="$(idle_usdc)"
  python3 -c "print(f'idle=\${int(\"$idle\")/1e6:,.6f}  need=\${int(\"$MIN_IDLE\")/1e6:,.0f}')"
  desk_status
  if python3 -c "import sys; sys.exit(0 if int('$idle') >= int('$MIN_IDLE') else 1)"; then
    echo "IDLE READY"
    if [[ "$AUTO_FIRE" == "1" ]]; then
      [[ -n "${PRIVATE_KEY:-}" ]] || { echo "PRIVATE_KEY missing"; exit 1; }
      KING_GO=1 FIRE_CASH=1 BORROW_USDC="$BORROW_USDC" MIN_IDLE="$MIN_IDLE" \
        forge script script/FireCashLeg500.s.sol:FireCashLeg500 \
        --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --broadcast --slow -vv
      echo "CASH LEG FIRED — exiting watch"
      exit 0
    else
      echo "Set AUTO_FIRE=1 to broadcast cash-leg"
    fi
  fi
  sleep "$SLEEP_SECS"
done
