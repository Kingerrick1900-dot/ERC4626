#!/usr/bin/env python3
"""
Move 4 — cbBTC/WETH Morpho Passport watcher

IF HOT holds blue-chip collateral AND market idle USDC > ask
THEN post collateral + borrow USDC -> KingVault

Does NOT siphon foreign idle into ySYNTH.
Does NOT flash-buy collateral (equity required).

Usage:
  python3 offchain/move4_passport.py
  ASSET=cbbtc ASK=100000000000 python3 offchain/move4_passport.py
  BROADCAST=1 PRIVATE_KEY=0x... ASSET=cbbtc python3 offchain/move4_passport.py
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import urllib.request

RPC = os.environ.get("RPC", "https://mainnet.base.org")
CAST = os.environ.get("CAST", "cast")
MORPHO_REST = "https://api.morpho.org"

HOT = "0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1"
KING_VAULT = "0xA1aFcb46a64C9173519180458C1cF302179c832a"
MORPHO = "0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb"
USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
CBBTC = "0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf"
WETH = "0x4200000000000000000000000000000000000006"
CBBTC_ID = "0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836"
WETH_ID = "0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda"

MIN_CBBTC = 10**5  # 0.001
MIN_WETH = 10**15  # 0.001


def cast(*args: str) -> str:
    return subprocess.check_output([CAST, *args, "--rpc-url", RPC], text=True).strip()


def u256(address: str, sig: str, *args: str) -> int:
    out = cast("call", address, sig, *args)
    return int(out.splitlines()[0].split()[0])


def rest_liq(mid: str) -> dict:
    url = f"{MORPHO_REST}/v0/blue/markets/8453:{mid}/liquidity"
    with urllib.request.urlopen(url, timeout=20) as r:
        return json.load(r)["data"]


def tick() -> int:
    asset = os.environ.get("ASSET", "cbbtc").lower()
    use_btc = not asset.startswith("w")
    coll = CBBTC if use_btc else WETH
    mid = CBBTC_ID if use_btc else WETH_ID
    min_coll = MIN_CBBTC if use_btc else MIN_WETH
    ask = int(os.environ.get("ASK", str(100_000 * 10**6)))
    broadcast = os.environ.get("BROADCAST", "0") == "1"

    bal = u256(coll, "balanceOf(address)(uint256)", HOT)
    vault = u256(USDC, "balanceOf(address)(uint256)", KING_VAULT)
    mkt = cast(
        "call",
        MORPHO,
        "market(bytes32)(uint128,uint128,uint128,uint128,uint128,uint256)",
        mid,
    )
    lines = [ln.split()[0] for ln in mkt.splitlines() if ln.strip()]
    supply, borrow = int(lines[0]), int(lines[2])
    idle = supply - borrow if supply > borrow else 0
    pos = cast("call", MORPHO, "position(bytes32,address)(uint256,uint128,uint128)", mid, HOT)
    posted = int([ln.split()[0] for ln in pos.splitlines() if ln.strip()][2])

    try:
        liq = rest_liq(mid)
        realloc = int(liq["reallocatable_liquidity"])
    except Exception as e:
        realloc = -1
        print(f"rest_err {e}")

    print(
        json.dumps(
            {
                "asset": "cbBTC" if use_btc else "WETH",
                "hotBal": bal,
                "posted": posted,
                "mktIdle": idle,
                "reallocatable": realloc,
                "ask": ask,
                "kingVaultUsdc": vault,
            }
        )
    )

    if bal < min_coll and posted == 0:
        print("NOOP: seed blue-chip on HOT (cbBTC/WETH) before Move 4 fire")
        return 0
    if idle < ask and realloc <= 0:
        print("NOOP: market idle < ask (optional: PA-fill foreign vaults into this market first)")
        return 0

    borrow_amt = min(ask, idle) if idle > 0 else 0
    if borrow_amt <= 0:
        print("NOOP: nothing borrowable yet")
        return 0

    if not broadcast:
        print(f"DRY OK: would post coll={bal} borrow={borrow_amt} -> KingVault")
        print("Set BROADCAST=1 PRIVATE_KEY=0x... to forge FireMove4Passport")
        return 0

    pk = os.environ.get("PRIVATE_KEY") or ""
    if not pk or pk.startswith("KAR_"):
        print("ERROR: PRIVATE_KEY required for broadcast")
        return 1

    root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    env = os.environ.copy()
    env["PRIVATE_KEY"] = pk
    env["BROADCAST"] = "1"
    env["ASSET"] = "cbbtc" if use_btc else "weth"
    env["BORROW_AMT"] = str(borrow_amt)
    env["COLL_AMT"] = str(bal)
    cmd = [
        "forge",
        "script",
        "script/FireMove4Passport.s.sol:FireMove4Passport",
        "--rpc-url",
        RPC,
        "--broadcast",
        "-vv",
    ]
    print("FIRE", " ".join(cmd))
    print(subprocess.check_output(cmd, cwd=root, env=env, text=True))
    return 0


if __name__ == "__main__":
    sys.exit(tick())
