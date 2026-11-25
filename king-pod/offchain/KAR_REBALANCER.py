#!/usr/bin/env python3
"""
KAR_REBALANCER.py — Move 3 (CORRECTED)
Morpho REST + RPC → PublicAllocator.reallocateTo → yRSS (ySYNTH) markets

Physics (do not ignore):
  PublicAllocator only moves liquidity *within one MetaMorpho vault*
  between markets that vault already has enabled + funded.
  It CANNOT siphon foreign cbBTC/WETH market idle into yRSS shares.
  Foreign idle is only borrowable by posting collateral on THAT market (Move 4).

Live Base (8453) — King sheet:
  PA     0xA090dD1a701408Df1d4d0B85b716c87565f90467
  yRSS   0xF80C0529bD94C773844E459853CD91B9263dD525  (yRSS-USDC / "ySYNTH")
  RSS mkt 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794

Usage:
  DRY (default):  python3 KAR_REBALANCER.py
  Once fire:      REQUIRED=100000000000 BROADCAST=1 PRIVATE_KEY=0x... python3 KAR_REBALANCER.py
  Loop:           LOOP=1 REQUIRED=100000000000 python3 KAR_REBALANCER.py
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from typing import Any

# === LIVE CONFIG (Base) ===
RPC = os.environ.get("RPC", "https://mainnet.base.org")
MORPHO_REST = "https://api.morpho.org"
PA = "0xA090dD1a701408Df1d4d0B85b716c87565f90467"
YRSS = "0xF80C0529bD94C773844E459853CD91B9263dD525"  # ySYNTH alias
MORPHO = "0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb"
KING_VAULT = "0xA1aFcb46a64C9173519180458C1cF302179c832a"

RSS_ID = "0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794"
CBBTC_ID = "0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836"
WETH_ID = "0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda"

USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
RSS = "0x7a305D07B537359cf468eAea9bb176E5308bC337"
RSS_ORACLE = "0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e"
IRM = "0x46415998764C29aB2a25CbeA6254146D50D22687"
LLTV_RSS = 770000000000000000

CAST = os.environ.get("CAST", "cast")


def _cast(*args: str) -> str:
    out = subprocess.check_output([CAST, *args, "--rpc-url", RPC], text=True)
    return out.strip()


def _cast_ints(address: str, sig: str, *args: str) -> list[int]:
    # cast call <address> <sig> [args...]
    raw = _cast("call", address, sig, *args)
    vals: list[int] = []
    for line in raw.splitlines():
        tok = line.strip().split()[0]
        try:
            vals.append(int(tok))
        except ValueError:
            continue
    return vals


def _rest(path: str) -> Any:
    url = f"{MORPHO_REST}{path}"
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.load(r)


def foreign_idle_diagnostic() -> list[dict]:
    """REST: show foreign cbBTC/WETH market idle (NOT siphonable into yRSS)."""
    pools = []
    for mid, name in ((CBBTC_ID, "cbBTC"), (WETH_ID, "WETH")):
        try:
            data = _rest(f"/v0/blue/markets/8453:{mid}/liquidity")["data"]
            pools.append(
                {
                    "market": name,
                    "market_id": mid,
                    "market_liquidity": int(data["market_liquidity"]),
                    "reallocatable_liquidity": int(data["reallocatable_liquidity"]),
                }
            )
        except (urllib.error.URLError, KeyError, ValueError) as e:
            pools.append({"market": name, "error": str(e)})
    return pools


def vault_pullable(mid: str) -> int:
    """USDC pullable from yRSS position on mid: min(assets, marketIdle, maxOut)."""
    pos = _cast_ints(
        MORPHO, "position(bytes32,address)(uint256,uint128,uint128)", mid, YRSS
    )
    shares = pos[0] if pos else 0
    if shares == 0:
        return 0
    mkt = _cast_ints(
        MORPHO, "market(bytes32)(uint128,uint128,uint128,uint128,uint128,uint256)", mid
    )
    sa, ss, ba = mkt[0], mkt[1], mkt[2]
    if ss == 0:
        return 0
    assets = shares * sa // ss
    idle = sa - ba if sa > ba else 0
    caps = _cast_ints(PA, "flowCaps(address,bytes32)(uint128,uint128)", YRSS, mid)
    max_out = caps[1] if len(caps) > 1 else 0
    return min(assets, idle, max_out)


def rss_max_in() -> int:
    caps = _cast_ints(PA, "flowCaps(address,bytes32)(uint128,uint128)", YRSS, RSS_ID)
    return caps[0] if caps else 0


def rss_util() -> tuple[float, int, int]:
    mkt = _cast_ints(
        MORPHO, "market(bytes32)(uint128,uint128,uint128,uint128,uint128,uint256)", RSS_ID
    )
    sa, ba = mkt[0], mkt[2]
    util = (ba / sa) if sa else 0.0
    idle = sa - ba if sa > ba else 0
    return util, sa, idle


def market_params(mid: str) -> dict:
    raw = _cast(
        "call",
        MORPHO,
        "idToMarketParams(bytes32)(address,address,address,address,uint256)",
        mid,
    )
    lines = [ln.strip().split()[0] for ln in raw.splitlines() if ln.strip()]
    return {
        "loanToken": lines[0],
        "collateralToken": lines[1],
        "oracle": lines[2],
        "irm": lines[3],
        "lltv": int(lines[4]),
    }


def collect_sources(required: int) -> list[tuple[str, int]]:
    """Prefer cbBTC/WETH on yRSS; then scan withdraw queue for any pullable."""
    sources: list[tuple[str, int]] = []
    need = required if required > 0 else 10**30

    def push(mid: str) -> None:
        nonlocal need
        if need <= 0:
            return
        p = vault_pullable(mid)
        if p <= 0:
            return
        take = min(p, need)
        sources.append((mid, take))
        need -= take

    push(CBBTC_ID)
    push(WETH_ID)

    if need > 0:
        n = _cast_ints(YRSS, "withdrawQueueLength()(uint256)")[0]
        for i in range(n):
            mid = _cast("call", YRSS, "withdrawQueue(uint256)(bytes32)", str(i)).split()[0]
            if mid in (RSS_ID, CBBTC_ID, WETH_ID) or any(m == mid for m, _ in sources):
                continue
            push(mid)
            if need <= 0:
                break
    return sources


def reallocate(sources: list[tuple[str, int]], required: int, broadcast: bool) -> str | None:
    """
    THE CORE (honest):
      IF yRSS pullable from source markets ≥ required
      AND RSS maxIn ≥ required
      → PublicAllocator.reallocateTo(yRSS, withdrawals, RSS market params)
    """
    total = sum(a for _, a in sources)
    max_in = rss_max_in()
    print(f"pullable={total} required={required} rssMaxIn={max_in}")

    if total < required:
        print("SKIP: yRSS source idle < required (foreign market idle ≠ vault liquidity)")
        return None
    if max_in < required:
        print("SKIP: RSS maxIn < required — curator must raise PA flow caps")
        return None

    # Sort by market id ascending (PA invariant)
    sources = sorted(sources, key=lambda x: int(x[0], 16))
    left = required
    w_args: list[str] = []
    for mid, amt in sources:
        take = min(amt, left)
        if take <= 0:
            continue
        p = market_params(mid)
        # (marketParams, amount) — cast calldata builder
        w_args.append(
            f"({p['loanToken']},{p['collateralToken']},{p['oracle']},{p['irm']},{p['lltv']},{take})"
        )
        left -= take
        if left <= 0:
            break

    fee = _cast_ints(PA, "fee(address)(uint256)", YRSS)[0]
    print(f"feeWei={fee} willPull={required - left}")
    print(f"sources_sorted={[m[:10] for m,_ in sources]}")

    if not broadcast:
        print("DRY OK — set BROADCAST=1 PRIVATE_KEY=0x... to fire via forge")
        return None

    pk = os.environ.get("PRIVATE_KEY")
    if not pk or pk.startswith("KAR_"):
        print("ERROR: set real PRIVATE_KEY in env (never commit keys)")
        return None

    # Broadcast through audited forge script (correct reallocateTo ABI)
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    env = os.environ.copy()
    env["REQUIRED"] = str(required)
    env["BROADCAST"] = "1"
    env["PRIVATE_KEY"] = pk
    cmd = [
        "forge",
        "script",
        "script/KarRebalancer.s.sol:KarRebalancer",
        "--rpc-url",
        RPC,
        "--broadcast",
        "-vv",
    ]
    print("FIRE: forge script KarRebalancer REQUIRED=", required)
    out = subprocess.check_output(cmd, cwd=root, env=env, text=True)
    print(out)
    return out


def tick(required: int, broadcast: bool) -> None:
    util, supply, idle = rss_util()
    print(f"RSS util={util*100:.2f}% supply={supply} idle={idle}")

    foreign = foreign_idle_diagnostic()
    print("foreign_idle (diagnostic only, NOT siphonable):", json.dumps(foreign))

    # Reallocate when RSS idle is thin OR always if REQUIRED set and util high
    if required <= 0:
        sources = collect_sources(0)
        print("sources(all pullable):", [(m[:10], a) for m, a in sources])
        print("DRY: set REQUIRED=<usdc_raw> to evaluate fire condition")
        return

    if util <= 0.95 and idle >= required:
        print("Vault/market already has idle ≥ required — no PA pull needed")
        return

    sources = collect_sources(required)
    print("sources:", [(m[:10], a) for m, a in sources])
    reallocate(sources, required, broadcast)


def main() -> int:
    required = int(os.environ.get("REQUIRED", "0"))
    broadcast = os.environ.get("BROADCAST", "0") == "1"
    loop = os.environ.get("LOOP", "0") == "1"
    print("KAR REBALANCER — Move 3 CORRECTED | yRSS PA sniper")
    print(f"PA={PA} YRSS={YRSS} KING_VAULT={KING_VAULT}")

    while True:
        try:
            tick(required, broadcast)
        except Exception as e:
            print(f"ERROR: {e}", file=sys.stderr)
            if not loop:
                return 1
        if not loop:
            break
        time.sleep(int(os.environ.get("INTERVAL", "30")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
