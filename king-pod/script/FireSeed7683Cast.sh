#!/usr/bin/env bash
# One tx at a time for EIP-7702 HOT (see deployments/OPS-WALLET-LOOP.md)
set -euo pipefail
export PATH="$HOME/.foundry/bin:$PATH"
RPC="${BASE_RPC_URL:-https://mainnet.base.org}"
PK="${PRIVATE_KEY:?set PRIVATE_KEY}"
HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
EUSD=0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a
GUSD=0x319A49BB274A826F889C6e7221FA82f24ac8bc5d
FILL=0x4C021c77633e9441be218d2A27a4B40c1Bd720Ab
LITEPSM=0xC28E7faA9aBb9E6d9627C612F0fb1Bec66E99F6B
COLL=0x99bE1Ec7Dba573da84cF42663B60A27108B6c3e8
GAS=500000

send() {
  echo ">>> $1"
  cast send "$2" "$3" "${@:4}" --rpc-url "$RPC" --private-key "$PK" --gas-limit "$GAS"
  sleep 2
}

echo "=== 1) 10% discount on Fill ==="
send "setFees" "$FILL" "setFees(uint256,uint256)" 1000 10

echo "=== 2) approve eUSD LitePSM + Fill ==="
send "approve LitePSM 2M" "$EUSD" "approve(address,uint256)" "$LITEPSM" 2000000000000000000000000
send "approve Fill 5M" "$EUSD" "approve(address,uint256)" "$FILL" 5000000000000000000000000

echo "=== 3) seed LitePSM 2M eUSD ==="
send "seedEusd LitePSM" "$LITEPSM" "seedEusd(uint256)" 2000000000000000000000000

echo "=== 4) seed Fill buffer 5M ==="
send "seedFillBuffer" "$FILL" "seedFillBuffer(uint256)" 5000000000000000000000000

DEADLINE=$(($(date +%s) + 604800))
echo "=== 5) openOrder 5M @ 4.5M USDC max, deadline $DEADLINE ==="
ORDER_TX=$(cast send "$FILL" "openOrder(address,uint256,uint256,uint32)(bytes32)" "$HOT" 5000000000000000000000000 4500000000 "$DEADLINE" --rpc-url "$RPC" --private-key "$PK" --gas-limit "$GAS" --slow --json)
echo "$ORDER_TX" | head -c 500

echo "=== 6) approve + lock 1B gUSD ==="
send "approve gUSD coll" "$GUSD" "approve(address,uint256)" "$COLL" 1000000000000000000000000000
send "lockGusd 1B" "$COLL" "lockGusd(uint256)" 1000000000000000000000000000

echo "=== LIVE STATE ==="
cast call "$FILL" "maxDiscountBps()(uint256)" --rpc-url "$RPC"
cast call "$EUSD" "balanceOf(address)(uint256)" "$FILL" --rpc-url "$RPC"
cast call "$LITEPSM" "eusdReserve()(uint256)" --rpc-url "$RPC"
cast call "$COLL" "gusdLocked()(uint256)" --rpc-url "$RPC"
cast call "$COLL" "maxDebtUsd6()(uint256)" --rpc-url "$RPC"
echo DONE
