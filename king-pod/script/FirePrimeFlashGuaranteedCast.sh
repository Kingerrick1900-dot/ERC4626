#!/usr/bin/env bash
# Deploy flash engine → wire → flash-fill open order. One tx at a time (EIP-7702 HOT).
set -euo pipefail
export PATH="$HOME/.foundry/bin:$PATH"
RPC="${BASE_RPC_URL:-https://mainnet.base.org}"
PK="${PRIVATE_KEY:?set PRIVATE_KEY}"

FILL=0x4C021c77633e9441be218d2A27a4B40c1Bd720Ab
CREDIT=0xc184A1d2486a24FAb9eB51764c9CF193AE3e6D15
ROUTER=0xA4E04b3160c7ed3cF1c4341DD2f67a06eFF85b6c
LANDING=0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357
HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
EUSD=0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a

ORDER_ID=0x2c85b27d5a04300779222173c2add2a7d71e366734c5b8aab435fba579f5eada
USDC_IN=4500000000000
GAS=900000

send() {
  echo ">>> $1"
  cast send "$2" "$3" "${@:4}" --rpc-url "$RPC" --private-key "$PK" --gas-limit "$GAS"
  sleep 2
}

echo "=== A) Deploy CrownPrimeFlashFillDraw ==="
cd /workspace/king-pod
KING_GO=1 FIRE_FLASH_FILL=1 PRIVATE_KEY="$PK" BASE_RPC_URL="$RPC" \
  forge script script/FirePrimeFlashFill.s.sol:FirePrimeFlashFill \
  --rpc-url "$RPC" --broadcast --slow 2>&1 | tee /tmp/flash-guaranteed-deploy.log

ENGINE=$(grep 'CrownPrimeFlashFillDraw' /tmp/flash-guaranteed-deploy.log | grep -oE '0x[a-fA-F0-9]{40}' | tail -1)
echo "ENGINE=$ENGINE"

echo "=== B) flashFillAndDraw ==="
send "flashFill" "$ENGINE" \
  "flashFillAndDraw(bytes32,uint256,address,uint256)" \
  "$ORDER_ID" "$USDC_IN" "$LANDING" 0

echo "=== C) arm router ==="
send "setArmed" "$ROUTER" "setArmed(bool)" true

echo "=== LIVE STATE ==="
echo "credit idle:" $(cast call "$CREDIT" "freeUsdc()(uint256)" --rpc-url "$RPC")
echo "credit debt:" $(cast call "$CREDIT" "debtOf(address)(uint256)" "$HOT" --rpc-url "$RPC")
echo "Landing USDC:" $(cast call "$USDC" "balanceOf(address)(uint256)" "$LANDING" --rpc-url "$RPC")
echo "router armed:" $(cast call "$ROUTER" "armed()(bool)" --rpc-url "$RPC")
echo "ENGINE=$ENGINE"
echo DONE
