#!/usr/bin/env bash
# Return path scoreboard — IN vs OUT (Landing + raised + borrows vs debt/fees)
set -euo pipefail
RPC="${BASE_RPC:-${RPC_URL:-https://mainnet.base.org}}"
LAND=0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357
HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
DESK=0xDbf7C4Ad01418ec1b753fa039d5e5B54aF4C065D
BOND=0x2D743eF8bf8eE188F44239Acc1e4795fe8cA3039
DUTCH=0x8A4C17c5FAB0ba334dAe4CdECa8BaC60a8Cc5E81
MORPHO=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
RSS77=0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794
BRETT_M=0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16
YRSS=0xF80C0529bD94C773844E459853CD91B9263dD525

usd() { python3 -c "print(f'\${int('$1')/1e6:,.2f}')"; }

debt_usdc() {
  local mkt="$1" who="$2"
  mapfile -t p < <(cast call "$MORPHO" "position(bytes32,address)(uint256,uint128,uint128)" "$mkt" "$who" --rpc-url "$RPC")
  mapfile -t m < <(cast call "$MORPHO" "market(bytes32)(uint128,uint128,uint128,uint128,uint128,uint128)" "$mkt" --rpc-url "$RPC")
  python3 -c "
bor=int('${p[1]}'.split()[0]); bA=int('${m[2]}'.split()[0]); bS=int('${m[3]}'.split()[0])
print(bor*bA//bS if bS else 0)
"
}

land=$(cast call $USDC "balanceOf(address)(uint256)" $LAND --rpc-url $RPC | awk '{print $1}')
desk=$(cast call $DESK "raisedUsdc()(uint256)" --rpc-url $RPC | awk '{print $1}')
bond=$(cast call $BOND "raisedUsdc()(uint256)" --rpc-url $RPC | awk '{print $1}')
dutch=$(cast call $DUTCH "raisedUsdc()(uint256)" --rpc-url $RPC | awk '{print $1}')
yrss=$(cast call $YRSS "totalAssets()(uint256)" --rpc-url $RPC | awk '{print $1}')
d77=$(debt_usdc $RSS77 $HOT)
dB=$(debt_usdc $BRETT_M $HOT)

echo "=== RETURN PATH ==="
echo "IN  Landing USDC:     $(usd "$land")"
echo "IN  Desk raised:      $(usd "$desk")"
echo "IN  Bond raised:      $(usd "$bond")"
echo "IN  Dutch raised:     $(usd "$dutch")"
echo "    yRSS TVL (yield):  $(usd "$yrss")"
echo "OUT Morpho debt RSS77: $(usd "$d77")"
echo "OUT Morpho debt BRETT: $(usd "$dB")"
python3 -c "
land=int('$land'); desk=int('$desk'); bond=int('$bond'); dutch=int('$dutch'); d=int('$d77')+int('$dB')
inflow=land+desk+bond+dutch
print('---')
print(f'Total IN tracked:  \${inflow/1e6:,.2f}')
print(f'Total debt OUT:    \${d/1e6:,.2f}')
print(f'Net (tracked):     \${(inflow-d)/1e6:,.2f}')
print('Grow IN: desk/bond fills · capture idle · yRSS fees · Ignition (building)')
"
