#!/usr/bin/env bash
# Capture \$700k seed the second it faces us — Credit V2 / desk / Landing.
# AUTO_FIRE=1 KING_OK=1 bash script/capture-zk-700k.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

RPC="${BASE_RPC:-${RPC_URL:-https://mainnet.base.org}}"
HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
COLD=0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357
USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
CREDIT=0x01814e15cF01DEcdC7239b739177C36acaBaBA54
DESK=0xDbf7C4Ad01418ec1b753fa039d5e5B54aF4C065D
GATE=0xAf9570a3Fe67988AE1c7d4dA0cD5c54CFE147205

TARGET="${TARGET_USDC:-700000000000}"  # $700k
SLEEP_SECS="${SLEEP_SECS:-30}"
AUTO_FIRE="${AUTO_FIRE:-1}"

bal() { cast call "$USDC" "balanceOf(address)(uint256)" "$1" --rpc-url "$RPC" | awk '{print $1}'; }
max_borrow() { cast call "$CREDIT" "maxBorrow(address)(uint256)" "$HOT" --rpc-url "$RPC" | awk '{print $1}'; }
desk_raised() { cast call "$DESK" "raisedUsdc()(uint256)" --rpc-url "$RPC" | awk '{print $1}'; }
proven() { cast call "$GATE" "isProven(address)(bool)" "$HOT" --rpc-url "$RPC"; }

echo "=== ZK 700K SEED CAPTURE ==="
echo "credit=$CREDIT cold=$COLD target=$TARGET auto=$AUTO_FIRE"

while true; do
  c="$(bal "$CREDIT")"
  land="$(bal "$COLD")"
  raised="$(desk_raised)"
  mb="$(max_borrow)"
  pr="$(proven)"
  python3 -c "print(f'proven={ \"$pr\".split()[0] } credit=\${int(\"$c\")/1e6:,.2f} maxBorrow=\${int(\"$mb\")/1e6:,.2f} deskRaised=\${int(\"$raised\")/1e6:,.2f} cold=\${int(\"$land\")/1e6:,.2f}')"

  # WIN: cold already has seed
  if python3 -c "import sys; sys.exit(0 if int('$land') >= int('$TARGET') else 1)"; then
    echo "SEED COMPLETE on cold Landing"
    exit 0
  fi

  # WIN: desk already raised seed
  if python3 -c "import sys; sys.exit(0 if int('$raised') >= int('$TARGET') else 1)"; then
    echo "SEED COMPLETE via desk raised → Landing"
    exit 0
  fi

  # CAPTURE: credit has liquidity and we can borrowTo cold
  if python3 -c "import sys; sys.exit(0 if int('$mb') > 0 else 1)"; then
    echo "CREDIT LIQUIDITY FACING US — atomic borrowTo cold"
    if [[ "$AUTO_FIRE" == "1" ]]; then
      if [[ "${KING_OK:-0}" != "1" ]]; then
        echo "Set KING_OK=1 to broadcast draw"
        exit 1
      fi
      amt="$mb"
      if python3 -c "import sys; sys.exit(0 if int('$mb') > int('$TARGET') else 1)"; then
        amt="$TARGET"
      fi
      KING_OK=1 FIRE_ATOMIC_COLD=1 DEPLOY=0 DRAW=1 CREDIT="$CREDIT" BORROW_AMT="$amt" \
        forge script script/FireZkAtomicCold.s.sol:FireZkAtomicCold \
        --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --broadcast
      land2="$(bal "$COLD")"
      python3 -c "print(f'cold_after=\${int(\"$land2\")/1e6:,.2f}')"
      if python3 -c "import sys; sys.exit(0 if int('$land2') >= int('$TARGET') else 1)"; then
        echo "SEED COMPLETE"
        exit 0
      fi
    fi
  fi

  sleep "$SLEEP_SECS"
done
