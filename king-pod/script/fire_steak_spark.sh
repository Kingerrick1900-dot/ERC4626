#!/usr/bin/env bash
# Fire: redeem Steakhouse USDC on HOT → Aerodrome USDC→ETH → CrownKingAgent.firePayroll
# Requires: PRIVATE_KEY (HOT), HOT ETH ≥ ~0.00001 after Landing tip. Set FIRE=1 to broadcast.
set -euo pipefail
export PATH="${HOME}/.foundry/bin:${PATH}"

RPC="${BASE_RPC_URL:-https://mainnet.base.org}"
HOT="${HOT:-0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1}"
STEAK="${STEAK:-0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183}"
USDC="${USDC:-0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913}"
WETH="${WETH:-0x4200000000000000000000000000000000000006}"
AERO_ROUTER="${AERO_ROUTER:-0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43}"
AERO_FACTORY="${AERO_FACTORY:-0x420DD381b31aEf6683db6B902084cB0FFECe40Da}"
AGENT="${AGENT:-0x128d1b9c8Ad4c47C3BCc12d237e78B95EF46f6bA}"
PAYROLL="${PAYROLL:-10000000000000000000000000}" # 10M eUSD

: "${PRIVATE_KEY:?set PRIVATE_KEY}"

addr=$(cast wallet address --private-key "$PRIVATE_KEY")
[[ "${addr,,}" == "${HOT,,}" ]] || { echo "PRIVATE_KEY is not HOT ($addr)"; exit 1; }

# sanity: router live
code=$(cast code "$AERO_ROUTER" --rpc-url "$RPC")
[[ "$code" != "0x" && -n "$code" ]] || { echo "Aero router has no code"; exit 1; }

eth=$(cast balance "$HOT" --rpc-url "$RPC")
usdc=$(cast call "$USDC" "balanceOf(address)(uint256)" "$HOT" --rpc-url "$RPC" | awk '{print $1}')
shares=$(cast call "$STEAK" "balanceOf(address)(uint256)" "$HOT" --rpc-url "$RPC" | awk '{print $1}')
nonce=$(cast nonce "$HOT" --rpc-url "$RPC")
gp=$(cast gas-price --rpc-url "$RPC")
gp=$((gp * 12 / 10))
[[ "$gp" -lt 6000000 ]] && gp=6000000

echo "HOT=$HOT nonce=$nonce ETH=$eth USDC=$usdc shares=$shares gp=$gp"

need=2500000000000 # ~0.0000025 ETH floor for redeem+swap+payroll
if [[ "$eth" -lt "$need" ]]; then
  echo "BLOCKED: HOT ETH $eth < $need — tip from Landing first (see FIRE-SPARK-CANCEL-REDEEM.md)"
  exit 2
fi

run() {
  if [[ "${FIRE:-0}" == "1" ]]; then
    cast send "$@" --private-key "$PRIVATE_KEY" --rpc-url "$RPC" --legacy --gas-price "$gp"
  else
    echo "DRY: cast send $*"
  fi
}

# 1) Redeem all Steakhouse shares → USDC on HOT
if [[ "$shares" -gt 0 ]]; then
  mr=$(cast call "$STEAK" "maxRedeem(address)(uint256)" "$HOT" --rpc-url "$RPC" | awk '{print $1}')
  echo "redeem maxRedeem=$mr"
  run "$STEAK" "redeem(uint256,address,address)" "$mr" "$HOT" "$HOT" --gas-limit 500000
  if [[ "${FIRE:-0}" == "1" ]]; then
    usdc=$(cast call "$USDC" "balanceOf(address)(uint256)" "$HOT" --rpc-url "$RPC" | awk '{print $1}')
  else
    usdc=$(cast call "$STEAK" "previewRedeem(uint256)(uint256)" "$mr" --rpc-url "$RPC" | awk '{print $1}')
  fi
fi
echo "USDC for swap=$usdc"

# 2) Swap USDC → ETH via Aerodrome (prefer stable USDC/WETH; fall back volatile)
if [[ "$usdc" -gt 0 ]]; then
  deadline=$(($(date +%s) + 600))
  stable_pool=$(cast call "$AERO_FACTORY" "getPool(address,address,bool)(address)" "$USDC" "$WETH" true --rpc-url "$RPC")
  use_stable=false
  [[ "${stable_pool,,}" != "0x0000000000000000000000000000000000000000" ]] && use_stable=true
  echo "approve + swapExactTokensForETH stable=$use_stable pool=$stable_pool"
  run "$USDC" "approve(address,uint256)" "$AERO_ROUTER" "$usdc" --gas-limit 100000
  # Route = (from, to, stable, factory)
  run "$AERO_ROUTER" \
    "swapExactTokensForETH(uint256,uint256,(address,address,bool,address)[],address,uint256)" \
    "$usdc" 1 "[(${USDC},${WETH},${use_stable},${AERO_FACTORY})]" "$HOT" "$deadline" \
    --gas-limit 450000
fi

eth=$(cast balance "$HOT" --rpc-url "$RPC")
echo "ETH after swap=$eth"

# 3) Fire payroll
echo "firePayroll $PAYROLL"
run "$AGENT" "firePayroll(uint256)" "$PAYROLL" --gas-limit 200000

echo "DONE eth=$(cast balance "$HOT" --rpc-url "$RPC") usdc=$(cast call "$USDC" "balanceOf(address)(uint256)" "$HOT" --rpc-url "$RPC")"
