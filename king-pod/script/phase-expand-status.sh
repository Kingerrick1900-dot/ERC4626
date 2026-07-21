#!/usr/bin/env bash
# Phase expand scoreboard — RSS + BRETT + desk + Landing + fees
set -euo pipefail
RPC="${BASE_RPC:-${RPC_URL:-https://mainnet.base.org}}"
MORPHO=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
RSS_M=0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794
BRETT_M=0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16
DESK=0xDbf7C4Ad01418ec1b753fa039d5e5B54aF4C065D
LAND=0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357
YRSS=0xF80C0529bD94C773844E459853CD91B9263dD525
USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
RSS=0x7a305D07B537359cf468eAea9bb176E5308bC337
BRETT=0x532f27101965dd16442E59d40670FaF5eBB142E4
PA=0xA090dD1a701408Df1d4d0B85b716c87565f90467
PHASE1=500000000000  # $500k

idle() {
  local mkt="$1"
  mapfile -t lines < <(cast call "$MORPHO" \
    "market(bytes32)(uint128,uint128,uint128,uint128,uint128,uint128)" \
    "$mkt" --rpc-url "$RPC")
  python3 -c "sup=int('${lines[0]}'.split()[0]); bor=int('${lines[2]}'.split()[0]); print(sup-bor if sup>bor else 0)"
}

usd() { python3 -c "print(f'\${int('$1')/1e6:,.2f}')"; }

echo "=== CHIEF 3-PHASE SCOREBOARD ==="
land=$(cast call $USDC "balanceOf(address)(uint256)" $LAND --rpc-url $RPC | awk '{print $1}')
raised=$(cast call $DESK "raisedUsdc()(uint256)" --rpc-url $RPC | awk '{print $1}')
sale=$(cast call $DESK "rssForSale()(uint256)" --rpc-url $RPC | awk '{print $1}')
live=$(cast call $DESK "live()(bool)" --rpc-url $RPC)
rss_idle=$(idle $RSS_M)
brett_idle=$(idle $BRETT_M)
yrss=$(cast call $YRSS "totalAssets()(uint256)" --rpc-url $RPC | awk '{print $1}')
fee=$(cast call $YRSS "fee()(uint96)" --rpc-url $RPC | awk '{print $1}')
hot_rss=$(cast call $RSS "balanceOf(address)(uint256)" $HOT --rpc-url $RPC | awk '{print $1}')
hot_brett=$(cast call $BRETT "balanceOf(address)(uint256)" $HOT --rpc-url $RPC | awk '{print $1}')
pa_rss=$(cast call $PA "flowCaps(address,bytes32)((uint128,uint128))" $YRSS $RSS_M --rpc-url $RPC)
pa_brett=$(cast call $PA "flowCaps(address,bytes32)((uint128,uint128))" $YRSS $BRETT_M --rpc-url $RPC)

echo "PHASE1 target: \$500,000.00"
echo "Landing USDC:  $(usd "$land")"
echo "Desk live=$live  rssForSale=$(python3 -c "print(int('$sale')/1e18)")  raised=$(usd "$raised")"
echo "RSS Morpho idle:   $(usd "$rss_idle")"
echo "BRETT Morpho idle: $(usd "$brett_idle")"
echo "yRSS TVL: $(usd "$yrss")  fee_bps=$(python3 -c "print(int(int('$fee')*10000/1e18))")"
echo "Hot RSS: $(python3 -c "print(f'{int(\"$hot_rss\")/1e18:,.0f}')")  Hot BRETT: $(python3 -c "print(int('$hot_brett'))")"
echo "PA yRSS RSS:   $pa_rss"
echo "PA yRSS BRETT: $pa_brett"

python3 - <<PY
land=int("$land"); raised=int("$raised"); rss_idle=int("$rss_idle"); phase1=int("$PHASE1")
gun_a = raised >= phase1
gun_b = rss_idle >= phase1
win = land >= phase1 or gun_a
print("---")
print(f"Gun A desk raised >= \$500k: {'YES' if gun_a else 'NO'}")
print(f"Gun B RSS idle >= \$500k:  {'YES' if gun_b else 'NO'}")
print(f"PHASE1 Landing win:        {'YES — FIRE CELEBRATE' if land >= phase1 else 'OPEN — send packets'}")
PY
