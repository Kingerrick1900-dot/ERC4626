#!/usr/bin/env bash
# Capture REAL Morpho idle → borrow spendable USDC to Hot (ops wallet).
# Debt access law: only fires FireAccessibleLoan (no fortress / flash self-seed).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

RPC="${BASE_RPC:-${RPC_URL:-https://mainnet.base.org}}"
MORPHO=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
RSS77=0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794
HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
# Default target $500k — override TARGET_USDC. MIN to fire once idle hits this.
TARGET="${TARGET_USDC:-500000000000}"
MIN_FIRE="${MIN_FIRE_USDC:-100000000}"  # $100 minimum accessible borrow
SLEEP_SECS="${SLEEP_SECS:-60}"
AUTO_FIRE="${AUTO_FIRE:-0}"

idle_usdc() {
  mapfile -t lines < <(cast call "$MORPHO" \
    "market(bytes32)(uint128,uint128,uint128,uint128,uint128,uint128)" \
    "$RSS77" --rpc-url "$RPC")
  python3 -c "s=int('${lines[0]}'.split()[0]); b=int('${lines[2]}'.split()[0]); print(s-b if s>b else 0)"
}

echo "=== ACCESSIBLE LOAN CAPTURE (Hot wallet) ==="
python3 -c "print(f'target=\${int(\"$TARGET\")/1e6:,.0f} min_fire=\${int(\"$MIN_FIRE\")/1e6:,.0f} auto=$AUTO_FIRE')"

while true; do
  idle=$(idle_usdc)
  hot=$(cast call $USDC "balanceOf(address)(uint256)" $HOT --rpc-url $RPC | awk '{print $1}')
  python3 -c "print(f'idle=\${int(\"$idle\")/1e6:,.2f} hotUsdc=\${int(\"$hot\")/1e6:,.2f}')"

  if python3 -c "import sys; sys.exit(0 if int('$idle') >= int('$MIN_FIRE') else 1)"; then
    borrow="$idle"
    if python3 -c "import sys; sys.exit(0 if int('$idle') > int('$TARGET') else 1)"; then
      borrow="$TARGET"
    fi
    echo "ACCESSIBLE LIQUIDITY READY borrow=$borrow"
    if [[ "$AUTO_FIRE" == "1" ]]; then
      KING_OK=1 KING_GO=1 FIRE_LOAN=1 RECEIVER=$HOT BORROW_USDC="$borrow" MIN_BORROW="$MIN_FIRE" \
        forge script script/FireAccessibleLoan.s.sol --rpc-url "$RPC" --broadcast --slow -vv && exit 0
    fi
  fi
  sleep "$SLEEP_SECS"
done
