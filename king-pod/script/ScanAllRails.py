#!/usr/bin/env python3
"""Scan ALL Kingdom USDC rails in one pass — not a 2-option menu.

Rails: Tenor RFQ offers, Morpho RSS idle, foreign PA maxIn, yRSS PA,
Bound credit liquidity, Vault V2 TVL, Aerodrome RSS/USDC depth, free RSS,
Landing balance. Prints FIRE lines when any rail can produce Landing USDC.

Usage:
  python3 ScanAllRails.py
  python3 ScanAllRails.py --poll --interval 60
  ASK_USDC=500000 python3 ScanAllRails.py
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

HOT = "0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1"
LANDING = "0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357"
RSS = "0x7a305D07B537359cf468eAea9bb176E5308bC337"
ELEPAN = "0x50639C42E2FFDEC4F68FB468968a55b3Af944583"
USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
MORPHO = "0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb"
PA = "0xA090dD1a701408Df1d4d0B85b716c87565f90467"
YRSS = "0xF80C0529bD94C773844E459853CD91B9263dD525"
V2 = "0xB96BcfFBB458581a3AF7fEd3150B7CD4b233A7b9"
CREDIT = "0x20B1513a137b9CB166E2cC15c405e842278E7D1A"
GATE = "0xab2856626BBd8E6fba9dB93783029eB973E8427F"
SPOIL = "0xcFF60f3B071c09C17853bA715ceDc0Fc2e6645Fa"
AERO = "0x2C4F14744B8b3D087b768D0764d983Acb46d537a"
RSS_MARKET = "0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794"
BUNDLER3 = "0x6BFd8137e702540E7A42B74178A4a49Ba43920C4"
RPC = os.environ.get("BASE_RPC") or os.environ.get("BASE_RPC_URL") or "https://mainnet.base.org"
TENOR_API = "https://api.tenor.finance/graphql"
INQUIRIES = [
    ("Armitage", "7e35d157-3dfe-40bc-81e5-e0841037976d"),
    ("Broadcast", "caaa6250-04c3-4b9a-98e1-64531f67be97"),
]
FOREIGN_VAULTS = [
    ("Gauntlet USDC Prime", "0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61"),
    ("Steakhouse Prime", "0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2"),
    ("Steakhouse USDC", "0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183"),
    ("Steakhouse HY", "0xBEEFA7B88064FeEF0cEe02AAeBBd95D30df3878F"),
]


def cast_nums(to: str, sig: str, *args: str) -> list[int]:
    out = subprocess.check_output(
        ["cast", "call", to, sig, *args, "--rpc-url", RPC], text=True
    ).strip()
    nums: list[int] = []
    for line in out.splitlines():
        tok = line.split()[0]
        if tok.startswith("0x") and len(tok) == 42:
            continue
        try:
            nums.append(int(tok, 0))
        except ValueError:
            pass
    return nums


def cast_bool(to: str, sig: str, *args: str) -> bool:
    out = subprocess.check_output(
        ["cast", "call", to, sig, *args, "--rpc-url", RPC], text=True
    ).strip().lower()
    return out.startswith("true")


def tenor_offers(inquiry_id: str) -> list[dict]:
    bearer = os.environ.get("TENOR_BEARER", "").strip()
    if not bearer:
        return []
    auth = bearer if bearer.lower().startswith("bearer ") else f"Bearer {bearer}"
    q = """
    query($w: Address!, $id: String!) {
      offersForInquiry(walletAddress: $w, quoteInquiryId: $id) {
        items {
          id
          rate
          maxAssets
          organization { name }
          collaterals { token }
        }
      }
    }
    """
    body = json.dumps(
        {"query": q, "variables": {"w": HOT, "id": inquiry_id}}
    ).encode()
    req = urllib.request.Request(
        TENOR_API,
        data=body,
        headers={"content-type": "application/json", "authorization": auth},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode())
        return data.get("data", {}).get("offersForInquiry", {}).get("items") or []
    except Exception as e:
        return [{"_error": str(e)}]


def scan(ask_usdc: int) -> dict:
    ask_raw = ask_usdc * 10**6
    fires: list[str] = []

    rss_hot = cast_nums(RSS, "balanceOf(address)(uint256)", HOT)[0]
    ele = cast_nums(ELEPAN, "balanceOf(address)(uint256)", HOT)[0]
    landing = cast_nums(USDC, "balanceOf(address)(uint256)", LANDING)[0]
    mkt = cast_nums(
        MORPHO,
        "market(bytes32)(uint128,uint128,uint128,uint128,uint128,uint128)",
        RSS_MARKET,
    )
    supply, borrow = mkt[0], mkt[2]
    idle = max(supply - borrow, 0)
    pos = cast_nums(
        MORPHO, "position(bytes32,address)(uint256,uint128,uint128)", RSS_MARKET, HOT
    )
    yrss_assets = cast_nums(YRSS, "totalAssets()(uint256)")[0]
    yrss_max_wd = cast_nums(YRSS, "maxWithdraw(address)(uint256)", HOT)[0]
    v2_assets = cast_nums(V2, "totalAssets()(uint256)")[0]
    credit_usdc = cast_nums(USDC, "balanceOf(address)(uint256)", CREDIT)[0]
    proven = cast_bool(GATE, "isProven(address)(bool)", HOT)
    try:
        max_borrow = cast_nums(CREDIT, "maxBorrow(address)(uint256)", HOT)[0]
    except Exception:
        max_borrow = 0
    aero_usdc = cast_nums(USDC, "balanceOf(address)(uint256)", AERO)[0]
    aero_rss = cast_nums(RSS, "balanceOf(address)(uint256)", AERO)[0]

    # R2 Morpho idle
    r2 = idle >= ask_raw and rss_hot >= 800_000 * 10**18
    if r2:
        fires.append(
            f"R2_MORPHO_IDLE FIRE=1 ASK_USDC={ask_raw} ADD_BORROW=1 "
            "forge script FireRssOptionCAtomicSeed --broadcast"
        )

    # R3 foreign PA
    pa_hits = []
    for name, vault in FOREIGN_VAULTS:
        caps = cast_nums(PA, "flowCaps(address,bytes32)(uint128,uint128)", vault, RSS_MARKET)
        max_in, max_out = caps[0], caps[1]
        pa_hits.append({"vault": name, "maxIn": max_in / 1e6, "maxOut": max_out / 1e6})
        if max_in >= ask_raw:
            fires.append(
                f"R3_PA_MAXIN {name} maxIn={max_in/1e6:.0f} → CrownSpoilFire {SPOIL}"
            )

    # R4 own yRSS PA
    ycaps = cast_nums(PA, "flowCaps(address,bytes32)(uint128,uint128)", YRSS, RSS_MARKET)
    r4_caps = {"maxIn": ycaps[0] / 1e6, "maxOut": ycaps[1] / 1e6}
    if ycaps[0] >= ask_raw and yrss_max_wd >= ask_raw:
        fires.append("R4_YRSS_PA spare idle withdrawable — reallocate+borrow Landing")

    # R5 bound credit
    if proven and credit_usdc >= ask_raw and max_borrow > 0:
        fires.append(
            f"R5_BOUND_CREDIT credit={credit_usdc/1e6:.0f} maxBorrow={max_borrow/1e6:.0f} "
            "→ Completer/AutoDraw Landing"
        )

    # R1 Tenor
    tenor = {}
    for label, qid in INQUIRIES:
        items = tenor_offers(qid)
        tenor[label] = {"inquiry": qid, "offers": items}
        for off in items:
            if "_error" in off:
                continue
            try:
                assets = int(off.get("maxAssets") or 0)
            except (TypeError, ValueError):
                assets = 0
            # maxAssets may already be 6dp
            if assets >= ask_raw:
                fires.append(
                    f"R1_TENOR {label} offer {off.get('id')} "
                    f"maxAssets={assets} org={off.get('organization')} — ACCEPT → Landing"
                )

    # R6 V2
    if v2_assets >= ask_raw:
        fires.append("R6_VAULT_V2 TVL sized — forceDeallocate exit path available")

    # R10 Aero — flag depth only; never auto-sell
    if aero_usdc >= ask_raw:
        fires.append(
            "R10_AERO depth>=ask — DOCTRINE loan≠sell; King GO required before any swap"
        )

    report = {
        "ask_usdc": ask_usdc,
        "landing_usdc": landing / 1e6,
        "rss_hot": rss_hot / 1e18,
        "elepan_untouched": ele / 1e8,
        "morpho": {
            "idle_usdc": idle / 1e6,
            "supply_usdc": supply / 1e6,
            "borrow_usdc": borrow / 1e6,
            "hot_borrow_shares": pos[1],
            "hot_coll_rss": pos[2] / 1e18,
        },
        "rails": {
            "R1_tenor": tenor,
            "R2_morpho_idle_ok": r2,
            "R3_foreign_pa": pa_hits,
            "R4_yrss_pa": r4_caps,
            "R4_yrss_maxWithdraw": yrss_max_wd / 1e6,
            "R4_yrss_totalAssets": yrss_assets / 1e6,
            "R5_bound": {
                "proven": proven,
                "credit_usdc": credit_usdc / 1e6,
                "maxBorrow": max_borrow / 1e6,
            },
            "R6_vault_v2_assets": v2_assets / 1e6,
            "R8_bundler3": BUNDLER3,
            "R10_aero": {"usdc": aero_usdc / 1e6, "rss": aero_rss / 1e18, "pool": AERO},
            "spoilFire": SPOIL,
        },
        "FIRE": fires,
        "any_fire": bool(fires),
    }
    return report


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--poll", action="store_true")
    ap.add_argument("--interval", type=int, default=60)
    ap.add_argument("--ask", type=int, default=int(os.environ.get("ASK_USDC", "500000")))
    args = ap.parse_args()

    # load tenor bearer if present
    envp = "/tmp/cursor/tenor_bearer.env"
    if os.path.isfile(envp):
        for line in open(envp):
            if "=" in line and not line.strip().startswith("#"):
                k, v = line.strip().split("=", 1)
                os.environ.setdefault(k, v.strip().strip('"').strip("'"))

    while True:
        try:
            report = scan(args.ask)
        except Exception as e:
            print(json.dumps({"scan_error": str(e)}), flush=True)
            if not args.poll:
                return 1
            time.sleep(args.interval)
            continue
        print(json.dumps(report, indent=2), flush=True)
        if report["FIRE"]:
            print("=== RAIL(S) GREEN — King GO to broadcast ===", file=sys.stderr)
            for f in report["FIRE"]:
                print("FIRE:", f, file=sys.stderr)
        else:
            print(
                "No rail green yet — all scanners still armed (not narrowed to 2).",
                file=sys.stderr,
            )
        if not args.poll:
            return 0 if report["any_fire"] else 2
        time.sleep(args.interval)


if __name__ == "__main__":
    raise SystemExit(main())
