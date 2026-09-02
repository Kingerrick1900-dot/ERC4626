#!/usr/bin/env bash
# Fill live credit with HOT USDC → arm → draw to Landing. No flash.
# Usage: AMT=1000000000000 PRIVATE_KEY=0x… bash king-pod/script/FireFillCreditDrawCast.sh
set -euo pipefail
export PATH="$HOME/.foundry/bin:$PATH"
RPC="${BASE_RPC_URL:-https://mainnet.base.org}"
PK="${PRIVATE_KEY:?set PRIVATE_KEY}"

HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
LANDING=0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357
USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
CREDIT=0x5568fE662363d7F3fa52349A99C9e19C6616B60d
ROUTER=0xBb3C372D4A0C398b6107f13ea4b1AB00B2b0A7aC
AMT="${AMT:?set AMT in USDC raw (e.g. 1000000000000 = \$1M)}"
GAS=400000

send() {
  echo ">>> $1"
  cast send "$2" "$3" "${@:4}" --rpc-url "$RPC" --private-key "$PK" --gas-limit "$GAS"
  sleep 2
}

BAL=$(cast call "$USDC" "balanceOf(address)(uint256)" "$HOT" --rpc-url "$RPC" | awk '{print $1}')
echo "HOT USDC: $BAL"
echo "need AMT: $AMT"
if [[ "$BAL" -lt "$AMT" ]]; then
  echo "BLOCK: HOT USDC < AMT — bridge/wire inventory to Base HOT first"
  echo "credit idle:" $(cast call "$CREDIT" "freeUsdc()(uint256)" --rpc-url "$RPC")
  exit 1
fi

echo "=== approve credit ==="
send "approve" "$USDC" "approve(address,uint256)" "$CREDIT" "$AMT"

echo "=== supply credit ==="
send "supply" "$CREDIT" "supply(uint256)" "$AMT"

IDLE=$(cast call "$CREDIT" "freeUsdc()(uint256)" --rpc-url "$RPC" | awk '{print $1}')
echo "credit idle: $IDLE"
if [[ "$IDLE" -lt "$AMT" ]]; then
  echo "BLOCK: supply did not land idle"
  exit 1
fi

echo "=== arm router ==="
send "setArmed" "$ROUTER" "setArmed(bool)" true

echo "=== draw to Landing ==="
send "draw" "$ROUTER" "draw(uint256,address)" "$AMT" "$LANDING"

echo "=== LIVE ==="
echo "Landing USDC:" $(cast call "$USDC" "balanceOf(address)(uint256)" "$LANDING" --rpc-url "$RPC")
echo "credit idle:" $(cast call "$CREDIT" "freeUsdc()(uint256)" --rpc-url "$RPC")
echo "credit debt:" $(cast call "$CREDIT" "debtOf(address)(uint256)" "$HOT" --rpc-url "$RPC")
echo "router armed:" $(cast call "$ROUTER" "armed()(bool)" --rpc-url "$RPC")
echo DONE
