#!/usr/bin/env bash
# Yield ignition scoreboard — the ONE King number: HOT USDC (not APY, not TVL)
set -euo pipefail
RPC="${BASE_RPC_URL:-${BASE_RPC:-https://mainnet.base.org}}"
HOT="${HOT:-0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1}"
LANDING="${LANDING:-0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357}"
USDC="${USDC:-0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913}"
TRANCHE="${TRANCHE:-0x8531F4DB622b982541A6715164d5A9dde58205b0}"
EUSD="${EUSD:-0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a}"

hot=$(cast call "$USDC" "balanceOf(address)(uint256)" "$HOT" --rpc-url "$RPC" | awk '{print $1}')
landing=$(cast call "$USDC" "balanceOf(address)(uint256)" "$LANDING" --rpc-url "$RPC" | awk '{print $1}')
deployed=$(cast call "$TRANCHE" "totalDeployed()(uint256)" --rpc-url "$RPC" 2>/dev/null | awk '{print $1}' || echo 0)
eusd=$(cast call "$EUSD" "balanceOf(address)(uint256)" "$LANDING" --rpc-url "$RPC" | awk '{print $1}')

echo "SCOREBOARD=HOT_USDC"
echo "hotUsdcRaw=$hot"
echo "hotUsdc=$(python3 -c "print(int('$hot')/1e6)")"
echo "landingUsdc=$(python3 -c "print(int('$landing')/1e6)")"
echo "trancheDeployed=$(python3 -c "print(int('${deployed:-0}')/1e6)")"
echo "landingEusdCold=$(python3 -c "print(int('$eusd')/1e18)")"
echo "IGNITION=$([ "${hot:-0}" != "0" ] && echo YES || echo NO)"
