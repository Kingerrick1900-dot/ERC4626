#!/usr/bin/env python3
"""Live readiness for $200M RSS/$1200 seed. No key needed. No USDC buffer."""
import subprocess, sys

RPC = __import__("os").environ.get("BASE_RPC_URL", "https://mainnet.base.org")
HOT = "0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1"
MORPHO = "0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb"
USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
RSS = "0x7a305D07B537359cf468eAea9bb176E5308bC337"
MID = "0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88"
ASK = 200_000_000 * 10**6
COLL = 250_000 * 10**18
MIN_FREE = 1_000_000 * 10**18

def cast(*args: str) -> str:
    return subprocess.check_output(["cast", *args, "--rpc-url", RPC], text=True).strip()

def first_int(s: str) -> int:
    return int(s.split()[0])

rss = first_int(cast("call", RSS, "balanceOf(address)(uint256)", HOT))
usdc = first_int(cast("call", USDC, "balanceOf(address)(uint256)", HOT))
flash = first_int(cast("call", USDC, "balanceOf(address)(uint256)", MORPHO))
eth_raw = subprocess.check_output(["cast", "balance", HOT, "--rpc-url", RPC], text=True).strip()
eth = int(eth_raw.split()[0])
pos = [first_int(ln) for ln in cast("call", MORPHO, "position(bytes32,address)(uint256,uint128,uint128)", MID, HOT).splitlines()]
sup, bor, coll = pos[0], pos[1], pos[2]

print(f"rssFree={rss}")
print(f"hotUsdc={usdc} (informational — not required)")
print(f"hotEthWei={eth}")
print(f"morphoFlash={flash}")
print(f"posSup={sup} posBor={bor} posColl={coll}")

ok = True
def check(name, cond, tip=""):
    global ok
    print(f"{name}={'OK' if cond else 'FAIL'}" + (f" {tip}" if (not cond and tip) else ""))
    if not cond:
        ok = False

check("RSS_HEADROOM", rss >= COLL + MIN_FREE)
check("FLASH_POOL", flash >= ASK)
check("POSITION_CLEAR", bor == 0 and coll == 0)
check("ETH_GAS", eth > 0, "need ETH for gas")
print("DUST_USDC=SKIP matched book washes — no buffer")
print(f"SEED_READY={1 if ok else 0}")
sys.exit(0 if ok else 1)
