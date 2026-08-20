#!/usr/bin/env bash
# Live readiness for $200M RSS/$1200 seed. No key needed.
set -euo pipefail
RPC="${BASE_RPC_URL:-https://mainnet.base.org}"
HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
MORPHO=0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
USDC=0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
RSS=0x7a305D07B537359cf468eAea9bb176E5308bC337
MID=0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88

raw_rss=$(cast call "$RSS" "balanceOf(address)(uint256)" "$HOT" --rpc-url "$RPC")
raw_usdc=$(cast call "$USDC" "balanceOf(address)(uint256)" "$HOT" --rpc-url "$RPC")
raw_flash=$(cast call "$USDC" "balanceOf(address)(uint256)" "$MORPHO" --rpc-url "$RPC")
raw_pos=$(cast call "$MORPHO" "position(bytes32,address)(uint256,uint128,uint128)" "$MID" "$HOT" --rpc-url "$RPC")

python3 - "$raw_rss" "$raw_usdc" "$raw_flash" "$raw_pos" <<'PY'
import sys
def first_int(s: str) -> int:
    tok = s.strip().split()[0]
    return int(tok)

rss = first_int(sys.argv[1])
usdc = first_int(sys.argv[2])
flash = first_int(sys.argv[3])
pos_lines = [ln.strip().split()[0] for ln in sys.argv[4].strip().splitlines() if ln.strip()]
sup = int(pos_lines[0]); bor = int(pos_lines[1]); coll = int(pos_lines[2])

ASK = 200_000_000 * 10**6
COLL = 250_000 * 10**18
MIN_FREE = 1_000_000 * 10**18
DUST = 2_000 * 10**6

print(f"rssFree={rss}")
print(f"hotUsdc={usdc}")
print(f"morphoFlash={flash}")
print(f"posSup={sup} posBor={bor} posColl={coll}")

ok = True
def check(name, cond, tip=""):
    global ok
    print(f"{name}={'OK' if cond else 'FAIL'}" + (f" {tip}" if not cond and tip else ""))
    if not cond:
        ok = False

check("RSS_HEADROOM", rss >= COLL + MIN_FREE)
check("FLASH_POOL", flash >= ASK)
check("DUST_USDC", usdc >= DUST, "need>=2000e6 on hot")
check("POSITION_CLEAR", bor == 0 and coll == 0)
print(f"SEED_READY={1 if ok else 0}")
raise SystemExit(0 if ok else 1)
PY
