#!/usr/bin/env bash
# Arm router + draw when credit has live idle. One tx at a time.
set -euo pipefail
export PATH="$HOME/.foundry/bin:$PATH"
RPC="${BASE_RPC_URL:-https://mainnet.base.org}"
PK="${PRIVATE_KEY:?set PRIVATE_KEY}"

ROUTER=0xBb3C372D4A0C398b6107f13ea4b1AB00B2b0A7aC
CREDIT=0x5568fE662363d7F3fa52349A99C9e19C6616B60d
USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
LANDING=0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357
HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1

DRAW_AMT="${DRAW_AMT:-4500000000000}"
GAS=400000

IDLE=$(cast call "$CREDIT" "freeUsdc()(uint256)" --rpc-url "$RPC")
echo "credit idle before: $IDLE"
if [[ "$IDLE" == "0" ]]; then
  echo "NO IDLE — wait for solver fill or supply USDC to credit first"
  exit 1
fi

send() {
  echo ">>> $1"
  cast send "$2" "$3" "${@:4}" --rpc-url "$RPC" --private-key "$PK" --gas-limit "$GAS"
  sleep 2
}

echo "=== arm router ==="
send "setArmed" "$ROUTER" "setArmed(bool)" true

echo "=== draw $DRAW_AMT to Landing ==="
send "draw" "$ROUTER" "draw(uint256,address)" "$DRAW_AMT" "$LANDING"

echo "Landing USDC:" $(cast call "$USDC" "balanceOf(address)(uint256)" "$LANDING" --rpc-url "$RPC")
echo "credit debt:" $(cast call "$CREDIT" "debtOf(address)(uint256)" "$HOT" --rpc-url "$RPC")
echo DONE
