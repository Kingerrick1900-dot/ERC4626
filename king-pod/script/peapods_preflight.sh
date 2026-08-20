#!/usr/bin/env python3
"""Peapods scream preflight — demand-first. Verify DEX exit for receipt/LP before 100% util fire.
No key needed. Exit 0 = scream-ready.
"""
import subprocess, sys, os

RPC = os.environ.get("BASE_RPC_URL", "https://mainnet.base.org")
HOT = "0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1"
RSS = "0x7a305D07B537359cf468eAea9bb176E5308bC337"
USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
MORPHO = "0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb"
FACTORY = "0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6"
# Optional: set after Peapods deploy
PRSS = os.environ.get("PRSS", "")
FUSDC = os.environ.get("FUSDC", "")
ASK_RSS = int(os.environ.get("ASK_RSS", "834"))  # default $1M scream; scale via env

def cast(*args):
    return subprocess.check_output(["cast", *args, "--rpc-url", RPC], text=True).strip()

def first_int(s):
    return int(s.split()[0])

rss = first_int(cast("call", RSS, "balanceOf(address)(uint256)", HOT))
flash = first_int(cast("call", USDC, "balanceOf(address)(uint256)", MORPHO))
need_rss = ASK_RSS * 10**18
need_usdc = ASK_RSS * 1200 * 10**6

print(f"ASK_RSS={ASK_RSS}")
print(f"needRss={need_rss}")
print(f"needUsdcFlash={need_usdc}")
print(f"hotRssFree={rss}")
print(f"morphoFlash={flash}")

ok = True
def check(name, cond, tip=""):
    global ok
    print(f"{name}={'OK' if cond else 'FAIL'}" + (f" {tip}" if not cond and tip else ""))
    if not cond:
        ok = False

check("RSS_FOR_SCREAM", rss >= need_rss, "need free RSS for wrap+LP")
check("FLASH_FOR_SCREAM", flash >= need_usdc, "Morpho flash pool")

# pfTKN / fUSDC LP depth — required BEFORE scream so suppliers can sell receipts
if PRSS and FUSDC:
    pair = cast("call", FACTORY, "getPair(address,address)(address)", PRSS, FUSDC)
    print(f"lpPair={pair}")
    if pair.lower() == "0x" + "0"*40:
        check("PFTKN_DEX", False, "create pRSS/fUSDC pair + seed LP before scream")
    else:
        # reserves
        try:
            r = cast("call", pair, "getReserves()(uint112,uint112,uint32)")
            lines = [ln.split()[0] for ln in r.splitlines() if ln.strip()]
            r0, r1 = int(lines[0]), int(lines[1])
            print(f"reserves={r0},{r1}")
            check("PFTKN_DEX_DEPTH", r0 > 0 and r1 > 0, "seed LP so pfTKN/receipt tradeable at 100% util")
        except Exception as e:
            check("PFTKN_DEX", False, str(e))
else:
    print("PFTKN_DEX=PENDING set PRSS+FUSDC after prep deploy; seed LP BEFORE FIRE_PEAPODS=1")
    print("ACTION= KING_GO=1 forge script FirePeapodsRss1200 (prep) → addLiquidity → then scream")

print(f"SCREAM_READY={1 if ok and PRSS and FUSDC else 0}")
print("ORDER= prep stack → seed DEX LP → FIRE_PEAPODS scream → Merkl fixed → trove mint")
sys.exit(0 if ok else 1)
