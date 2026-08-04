#!/usr/bin/env python3
"""Parallel succeed watch — Track A (USDC/credit) + Track B (Tenor offers).

On hot/credit USDC >= ask → FireFundBoundCredit complete (classic or note Permit2).
On Tenor offer → print ACCEPT NOW (manual accept; wallet session).

Usage:
  TENOR_BEARER=... python3 SucceedWatch.py --ask 490000 --poll
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

HOT = "0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1"
USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
CREDIT = "0x20B1513a137b9CB166E2cC15c405e842278E7D1A"
P2 = "0xA247c1d0Ad4E7690764E456E5d8d315bA2912468"
LANDING = "0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357"
RPC = os.environ.get("BASE_RPC") or os.environ.get("BASE_RPC_URL") or "https://mainnet.base.org"
API = "https://api.tenor.finance/graphql"
INQUIRIES = [
    ("Armitage", "7e35d157-3dfe-40bc-81e5-e0841037976d"),
    ("Broadcast", "caaa6250-04c3-4b9a-98e1-64531f67be97"),
]
HERE = Path(__file__).resolve().parent


def load_env() -> None:
    for p in ("/tmp/cursor/hot_pk.env", "/tmp/cursor/tenor_bearer.env"):
        if os.path.isfile(p):
            for line in open(p):
                if "=" in line and not line.strip().startswith("#"):
                    k, v = line.strip().split("=", 1)
                    os.environ.setdefault(k, v.strip().strip('"').strip("'"))


def bal(addr: str) -> int:
    out = subprocess.check_output(
        ["cast", "call", USDC, "balanceOf(address)(uint256)", addr, "--rpc-url", RPC],
        text=True,
    ).strip()
    return int(out.split()[0])


def tenor_offers(qid: str) -> list:
    bearer = os.environ.get("TENOR_BEARER", "").strip()
    if not bearer:
        return []
    auth = bearer if bearer.lower().startswith("bearer ") else f"Bearer {bearer}"
    q = """query($w:Address!,$id:String!){
      offersForInquiry(walletAddress:$w, quoteInquiryId:$id){
        items { id maxAssets rate organization { name } }
      }}"""
    body = json.dumps({"query": q, "variables": {"w": HOT, "id": qid}}).encode()
    req = urllib.request.Request(
        API,
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


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ask", type=int, default=490_000)
    ap.add_argument("--poll", action="store_true")
    ap.add_argument("--interval", type=int, default=45)
    ap.add_argument("--auto-complete", action="store_true", help="Fire complete if hot USDC >= ask")
    args = ap.parse_args()
    load_env()
    ask_raw = args.ask * 10**6

    print(
        f"SUCCEED WATCH ask=${args.ask} P2={P2} Landing={LANDING}",
        flush=True,
    )
    while True:
        hot = bal(HOT)
        credit = bal(CREDIT)
        landing = bal(LANDING)
        print(
            json.dumps(
                {
                    "hot_usdc": hot / 1e6,
                    "credit_usdc": credit / 1e6,
                    "landing_usdc": landing / 1e6,
                    "p2_completer": P2,
                }
            ),
            flush=True,
        )

        if hot >= ask_raw or credit > 0:
            print("TRACK_A_GREEN — USDC present", file=sys.stderr)
            if args.auto_complete and hot >= ask_raw:
                cmd = [
                    sys.executable,
                    str(HERE / "FireFundBoundCredit.py"),
                    "--fire",
                    "--mode",
                    "complete",
                    "--amount",
                    str(args.ask),
                ]
                print("AUTO_COMPLETE", " ".join(cmd), file=sys.stderr)
                return subprocess.run(cmd).returncode
            if credit > 0:
                print("POKE_HINT: python3 FireFundBoundCredit.py --fire --mode poke", file=sys.stderr)

        for label, qid in INQUIRIES:
            items = tenor_offers(qid)
            for off in items:
                if "_error" in off:
                    continue
                try:
                    assets = int(off.get("maxAssets") or 0)
                except (TypeError, ValueError):
                    assets = 0
                if assets >= 100_000 * 10**6:
                    print(
                        f"TRACK_B_GREEN {label} offer={off.get('id')} "
                        f"maxAssets={assets} — ACCEPT ON TENOR NOW → route Landing",
                        file=sys.stderr,
                    )

        if not args.poll:
            return 0
        time.sleep(args.interval)


if __name__ == "__main__":
    raise SystemExit(main())
