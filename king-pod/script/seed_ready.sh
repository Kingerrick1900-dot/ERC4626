#!/usr/bin/env bash
# Live readiness for $200M RSS/$1200 seed. No key needed.
set -euo pipefail
RPC="${BASE_RPC_URL:-https://mainnet.base.org}"
HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
MORPHO=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
RSS=0x7a305D07B537359cf468eAea9bb176E5308bC337
MID=0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88
ASK=200000000000000
COLL=250000000000000000000000
MIN_FREE=1000000000000000000000000
DUST=2000000000

num() { cast --to-dec "$1" 2>/dev/null || echo "$1" | awk '{print $1}'; }

rss=$(num "$(cast call "$RSS" "balanceOf(address)(uint256)" "$HOT" --rpc-url "$RPC")")
usdc=$(num "$(cast call "$USDC" "balanceOf(address)(uint256)" "$HOT" --rpc-url "$RPC")")
flash=$(num "$(cast call "$USDC" "balanceOf(address)(uint256)" "$MORPHO" --rpc-url "$RPC")")
read -r sup bor coll < <(cast call "$MORPHO" "position(bytes32,address)(uint256,uint128,uint128)" "$MID" "$HOT" --rpc-url "$RPC" | awk '{print $1}' | tr '\n' ' ')

echo "rssFree=$rss"
echo "hotUsdc=$usdc"
echo "morphoFlash=$flash"
echo "posSup=$sup posBor=$bor posColl=$coll"

fail=0
awk -v rss="$rss" -v usdc="$usdc" -v flash="$flash" -v ask="$ASK" -v coll="$COLL" -v minf="$MIN_FREE" -v dust="$DUST" -v bor="$bor" -v pcoll="$coll" '
BEGIN {
  ok=1
  if (rss+0 < coll+minf) { print "RSS_HEADROOM=FAIL"; ok=0 } else print "RSS_HEADROOM=OK"
  if (flash+0 < ask) { print "FLASH_POOL=FAIL"; ok=0 } else print "FLASH_POOL=OK"
  if (usdc+0 < dust) { print "DUST_USDC=FAIL need>=2000e6"; ok=0 } else print "DUST_USDC=OK"
  if ((bor+0)!=0 || (pcoll+0)!=0) { print "POSITION_CLEAR=FAIL"; ok=0 } else print "POSITION_CLEAR=OK"
  if (ok) print "SEED_READY=1"; else print "SEED_READY=0"
  exit ok?0:1
}'
