#!/usr/bin/env python3
"""Live scoreboard: Landing USDC vs $700k and Morpho idle. Read-only."""
import json
import urllib.request

UA = "Mozilla/5.0 (compatible; king-scoreboard/1.0)"
BASE = "https://base.publicnode.com"
LANDING = "0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357"
HOT = "0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1"
USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
MORPHO = "0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb"
MID = "40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794"
WANT = 700_000 * 10**6


def rpc(method, params):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    req = urllib.request.Request(
        BASE, data=body, headers={"Content-Type": "application/json", "User-Agent": UA}
    )
    with urllib.request.urlopen(req, timeout=20) as r:
        data = json.loads(r.read().decode())
    if "error" in data:
        raise RuntimeError(data["error"])
    return data["result"]


def u256(h):
    return int(h, 16) if h and h != "0x" else 0


def main():
    landing = u256(rpc("eth_call", [{"to": USDC, "data": "0x70a08231" + LANDING[2:].lower().zfill(64)}, "latest"]))
    hot = u256(rpc("eth_call", [{"to": USDC, "data": "0x70a08231" + HOT[2:].lower().zfill(64)}, "latest"]))
    mkt = rpc("eth_call", [{"to": MORPHO, "data": "0x5c60e39a" + MID}, "latest"])[2:]
    supply = int(mkt[0:64], 16)
    borrow = int(mkt[128:192], 16)
    idle = max(supply - borrow, 0)
    print(f"landing_usdc {landing / 1e6:.6f}")
    print(f"hot_usdc     {hot / 1e6:.6f}")
    print(f"rss_idle     {idle / 1e6:.6f}")
    print(f"scoreboard   {'HIT' if landing >= WANT else 'MISS'}")
    print(f"borrow_ready {'YES' if idle >= WANT else 'NO — need unmatched idle or wire'}")


if __name__ == "__main__":
    main()
