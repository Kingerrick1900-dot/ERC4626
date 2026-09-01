#!/usr/bin/env bash
# Cancel $4,500 typo order + reopen at $4.5M. One tx at a time (EIP-7702 HOT).
set -euo pipefail
export PATH="$HOME/.foundry/bin:$PATH"
RPC="${BASE_RPC_URL:-https://mainnet.base.org}"
PK="${PRIVATE_KEY:?set PRIVATE_KEY}"

HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
FILL=0x4C021c77633e9441be218d2A27a4B40c1Bd720Ab
CREDIT=0xc184A1d2486a24FAb9eB51764c9CF193AE3e6D15
EUSD=0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a

OLD_ORDER=0x2b75086050a42e49192593ad9d97cec9a7f0e829cbf514fce982bf0940a9b88c
# 4500000 * 1e6 = 4500000000000 ($4.5M USDC, 6dp). NOT 4500000000 ($4,500).
MAX_USDC_IN=4500000000000
ORDER_EUSD=5000000000000000000000000
GAS=500000

send() {
  echo ">>> $1"
  cast send "$2" "$3" "${@:4}" --rpc-url "$RPC" --private-key "$PK" --gas-limit "$GAS"
  sleep 2
}

echo "=== 1) Cancel broken order (maxUsdcIn was \$4,500) ==="
send "cancel" "$FILL" "cancel(bytes32)" "$OLD_ORDER"

echo "=== 2) setFees(1000,0) ==="
send "setFees" "$FILL" "setFees(uint256,uint256)" 1000 0

DEADLINE=$(($(date +%s) + 604800))
echo "=== 3) openOrder 5M eUSD @ \$4.5M maxUsdcIn=$MAX_USDC_IN deadline=$DEADLINE ==="
send "openOrder" "$FILL" "openOrder(address,uint256,uint256,uint32)" "$HOT" "$ORDER_EUSD" "$MAX_USDC_IN" "$DEADLINE"

echo "=== LIVE ==="
echo "credit idle:" $(cast call "$CREDIT" "freeUsdc()(uint256)" --rpc-url "$RPC")
echo "Fill eUSD:" $(cast call "$EUSD" "balanceOf(address)(uint256)" "$FILL" --rpc-url "$RPC")
echo "protocolFeeBps:" $(cast call "$FILL" "protocolFeeBps()(uint256)" --rpc-url "$RPC")
echo DONE
