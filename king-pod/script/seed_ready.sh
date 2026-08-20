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

rss=$(cast call "$RSS" "balanceOf(address)(uint256)" "$HOT" --rpc-url "$RPC")
usdc=$(cast call "$USDC" "balanceOf(address)(uint256)" "$HOT" --rpc-url "$RPC")
flash=$(cast call "$USDC" "balanceOf(address)(uint256)" "$MORPHO" --rpc-url "$RPC")
pos=$(cast call "$MORPHO" "position(bytes32,address)(uint256,uint128,uint128)" "$MID" "$HOT" --rpc-url "$RPC")

echo "rssFree=$rss"
echo "hotUsdc=$usdc"
echo "morphoFlash=$flash"
echo "position=$pos"

ok=1
python3 - <<PY
rss, usdc, flash = int("$rss"), int("$usdc"), int("$flash")
ask, coll, min_free, dust = $ASK, $COLL, $MIN_FREE, $DUST
checks = [
    ("RSS_HEADROOM", rss >= coll + min_free),
    ("FLASH_POOL", flash >= ask),
    ("DUST_USDC", usdc >= dust),
]
for name, good in checks:
    print(f"{name}={'OK' if good else 'FAIL'}")
    if not good:
        raise SystemExit(1)
print("SEED_READY=1")
PY
