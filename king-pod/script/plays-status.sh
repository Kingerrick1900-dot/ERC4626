#!/usr/bin/env bash
# Post-zero play scoreboard — what's live, shelved, and what fires when capital moves
set -euo pipefail
RPC="${BASE_RPC:-${RPC_URL:-https://mainnet.base.org}}"
HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
LAND=0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357
DESK=0xDbf7C4Ad01418ec1b753fa039d5e5B54aF4C065D
HELPER=0xeA454FAD0115A8131C3E10bC117A6584f649356b
RSS=0x7a305D07B537359cf468eAea9bb176E5308bC337
USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
MORPHO=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
YRSS=0xF80C0529bD94C773844E459853CD91B9263dD525
RSS77=0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794
RSS91=0x3a5ba11fdbd0a3ef70e98445afeaa5d3d73aac297bcfdcca120114bff5954126
BOND=0x2D743eF8bf8eE188F44239Acc1e4795fe8cA3039

usd() { python3 -c "print(f'\${int('$1')/1e6:,.2f}')"; }
rss_amt() { python3 -c "print(f'{int('$1')/1e18:,.0f}')"; }

idle() {
  mapfile -t L < <(cast call "$MORPHO" "market(bytes32)(uint128,uint128,uint128,uint128,uint128,uint128)" "$1" --rpc-url "$RPC")
  python3 -c "s=int('${L[0]}'.split()[0]); b=int('${L[2]}'.split()[0]); print(s-b if s>b else 0)"
}

hot_rss=$(cast call "$RSS" "balanceOf(address)(uint256)" "$HOT" --rpc-url "$RPC" | awk '{print $1}')
land_usdc=$(cast call "$USDC" "balanceOf(address)(uint256)" "$LAND" --rpc-url "$RPC" | awk '{print $1}')
desk_live=$(cast call "$DESK" "live()(bool)" --rpc-url "$RPC")
desk_sale=$(cast call "$DESK" "rssForSale()(uint256)" --rpc-url "$RPC" | awk '{print $1}')
desk_raised=$(cast call "$DESK" "raisedUsdc()(uint256)" --rpc-url "$RPC" | awk '{print $1}')
yrss_tvl=$(cast call "$YRSS" "totalAssets()(uint256)" --rpc-url "$RPC" | awk '{print $1}')
pos77=$(cast call "$MORPHO" "position(bytes32,address)(uint256,uint128,uint128)" "$RSS77" "$HOT" --rpc-url "$RPC")
bor77=$(echo "$pos77" | sed -n '2p' | awk '{print $1}')
coll77=$(echo "$pos77" | sed -n '3p' | awk '{print $1}')
idle77=$(idle "$RSS77")
idle91=$(idle "$RSS91")
bond_live=$(cast call "$BOND" "live()(bool)" --rpc-url "$RPC")
bond_stock=$(cast call "$BOND" "rssForBond()(uint256)" --rpc-url "$RPC" | awk '{print $1}')
bond_raised=$(cast call "$BOND" "raisedUsdc()(uint256)" --rpc-url "$RPC" | awk '{print $1}')

echo "=== POST-ZERO PLAY BOARD ==="
echo "Hot RSS:     $(rss_amt "$hot_rss")"
echo "Landing:     $(usd "$land_usdc")"
echo "Desk live:   $desk_live  forSale=$(rss_amt "$desk_sale") RSS @ \$1  raised=$(usd "$desk_raised")"
echo "yRSS TVL:    $(usd "$yrss_tvl")"
echo "Morpho77:    bor=$bor77 coll=$coll77 idle=$(usd "$idle77")"
echo "Morpho91:    idle=$(usd "$idle91") (high-LLTV book seeded)"
echo "Bond live:   $bond_live  forBond=$(rss_amt "$bond_stock") RSS @ \$0.97  raised=$(usd "$bond_raised")"
echo ""
echo "PLAY 1 DESK @ \$1     LIVE — helper $HELPER fillPhase1()"
echo "PLAY 2 BOND @ \$0.97   LIVE — $BOND bondWithUsdc(amount)"
echo "PLAY 3 CREDIT LINE      SHELF — FireArmCreditLine when idle faces book"
echo "PLAY 4 yRSS RE-ARM      SHELF — after USDC inflow"
echo ""
echo "Not waiting: outbound packets + bond rail = commerce. No live fire without KING_OK."
