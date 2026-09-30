#!/usr/bin/env bash
# Yield ignition scoreboard — HOT hard assets (USDC · cbBTC · WETH). Not APY. Not TVL.
set -euo pipefail
RPC="${BASE_RPC_URL:-${BASE_RPC:-https://mainnet.base.org}}"
HOT="${HOT:-0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1}"
LANDING="${LANDING:-0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357}"
USDC="${USDC:-0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913}"
CBBTC="${CBBTC:-0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf}"
WETH="${WETH:-0x4200000000000000000000000000000000000006}"
EUSD="${EUSD:-0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a}"
TRANCHE="${TRANCHE:-0x8531F4DB622b982541A6715164d5A9dde58205b0}"
CURATOR_NATIVE="${CURATOR_NATIVE:-}"

raw() { cast call "$1" "balanceOf(address)(uint256)" "$2" --rpc-url "$RPC" | awk '{print $1}'; }

hot_usdc=$(raw "$USDC" "$HOT")
hot_btc=$(raw "$CBBTC" "$HOT")
hot_weth=$(raw "$WETH" "$HOT")
hot_eusd=$(raw "$EUSD" "$HOT")
land_usdc=$(raw "$USDC" "$LANDING")
land_eusd=$(raw "$EUSD" "$LANDING")

echo "SCOREBOARD=HOT_HARD_ASSETS"
echo "hotUsdc=$(python3 -c "print(int('$hot_usdc')/1e6)")"
echo "hotCbBtc=$(python3 -c "print(int('$hot_btc')/1e8)")"
echo "hotWeth=$(python3 -c "print(int('$hot_weth')/1e18)")"
echo "hotEusd=$(python3 -c "print(int('$hot_eusd')/1e18)")"
echo "landingUsdc=$(python3 -c "print(int('$land_usdc')/1e6)")"
echo "landingEusdCold=$(python3 -c "print(int('$land_eusd')/1e18)")"
if [ -n "$CURATOR_NATIVE" ]; then
  minted=$(cast call "$CURATOR_NATIVE" "totalMinted()(uint256)" --rpc-url "$RPC" | awk '{print $1}')
  echo "nativeMinted=$(python3 -c "print(int('$minted')/1e18)")"
fi
deployed=$(cast call "$TRANCHE" "totalDeployed()(uint256)" --rpc-url "$RPC" 2>/dev/null | awk '{print $1}' || echo 0)
echo "usdcTrancheDeployed=$(python3 -c "print(int('${deployed:-0}')/1e6)")"
ignition=NO
python3 -c "import sys; sys.exit(0 if int('$hot_usdc')+int('$hot_btc')+int('$hot_weth')>0 else 1)" && ignition=YES || true
echo "IGNITION=$ignition"
