#!/usr/bin/env bash
# EIP-7702 HOT: one tx at a time (see deployments/OPS-WALLET-LOOP.md)
set -euo pipefail
export PATH="$HOME/.foundry/bin:$PATH"
RPC="${BASE_RPC_URL:-https://mainnet.base.org}"
PK="${PRIVATE_KEY:?set PRIVATE_KEY}"

MORPHO=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
FILL=0x4C021c77633e9441be218d2A27a4B40c1Bd720Ab
CREDIT=0xc184A1d2486a24FAb9eB51764c9CF193AE3e6D15
TREASURY=0xA1215D21eBC646F609d2CcAAc0cD4E00bF0ebd97
ROUTER=0xA4E04b3160c7ed3cF1c4341DD2f67a06eFF85b6c
LANDING=0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357
ORDER_ID=0x2b75086050a42e49192593ad9d97cec9a7f0e829cbf514fce982bf0940a9b88c
USDC_IN=4500000000000
GAS=800000

send() {
  echo ">>> $1"
  cast send "$2" "$3" "${@:4}" --rpc-url "$RPC" --private-key "$PK" --gas-limit "$GAS"
  sleep 2
}

ENGINE="${FLASH_ENGINE:-}"

if [[ -z "$ENGINE" ]]; then
  echo "=== Deploy CrownPrimeFlashFillDraw ==="
  KING_GO=1 FIRE_FLASH_FILL=1 PRIVATE_KEY="$PK" BASE_RPC_URL="$RPC" \
    forge script script/FirePrimeFlashFill.s.sol:FirePrimeFlashFill \
    --rpc-url "$RPC" --broadcast --slow 2>&1 | tee /tmp/flash-deploy.log
  ENGINE=$(grep -oE 'CrownPrimeFlashFillDraw [0-9a-fA-Fx]{42}' /tmp/flash-deploy.log | awk '{print $2}' | tail -1)
  echo "ENGINE=$ENGINE"
fi

echo "=== flashFillAndDraw (fee=0, round-trip) ==="
send "flashFill" "$ENGINE" \
  "flashFillAndDraw(bytes32,uint256,address,uint256)" \
  "$ORDER_ID" "$USDC_IN" "$LANDING" 0

echo "=== LIVE STATE ==="
echo "credit idle:" $(cast call "$CREDIT" "freeUsdc()(uint256)" --rpc-url "$RPC")
echo "credit debt:" $(cast call "$CREDIT" "debtOf(address)(uint256)" 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1 --rpc-url "$RPC")
echo "Landing USDC:" $(cast call "$USDC" "balanceOf(address)(uint256)" "$LANDING" --rpc-url "$RPC")
echo "order status:" $(cast call "$FILL" "orders(bytes32)(address,address,uint256,uint256,uint32,uint8,address,uint256)" "$ORDER_ID" --rpc-url "$RPC" | awk '{print $(NF-1)}')
echo DONE
