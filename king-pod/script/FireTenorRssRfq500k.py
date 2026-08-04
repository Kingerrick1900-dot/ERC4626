#!/usr/bin/env python3
"""Option C — Tenor OTC RFQ: $500k USDC borrow vs TRUE RSS → Armitage (+ optional broadcast).

King order 2026-08-04: Try C $500k. Elepan NEVER touched.
Collateral = true RSS 0x7a305… (18dp), oracle = Morpho RSS market oracle 0x284EC3…

Usage:
  python3 FireTenorRssRfq500k.py --print-only
  TENOR_BEARER=... python3 FireTenorRssRfq500k.py --fire
  TENOR_BEARER=... python3 FireTenorRssRfq500k.py --fire --broadcast-all
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
from pathlib import Path

API = "https://api.tenor.finance/graphql"
APP_OTC = "https://app.tenor.finance/otc"
HOT = "0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1"
LANDING = "0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357"
USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
# TRUE RSS — not Elepan
RSS = "0x7a305D07B537359cf468eAea9bb176E5308bC337"
ELEPAN = "0x50639C42E2FFDEC4F68FB468968a55b3Af944583"  # denylist
ORACLE = "0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e"  # RSS Morpho $1 oracle
LLTV = "770000000000000000"
ASK = "500000000000"  # $500k USDC 6dp
ASK_HUMAN = 500_000
ARMITAGE = "123cf521-4b9e-4b58-9335-d6d0b35f8b95"
LIQ_CURSOR_MID = "300000000000000000"
BASE_RPC = os.environ.get("BASE_RPC") or os.environ.get("BASE_RPC_URL") or "https://mainnet.base.org"
PACKET = Path(__file__).resolve().parents[1] / "deployments" / "tenor-rss-rfq-500k.json"


def gql(query: str, variables: dict | None = None, auth: bool = False) -> dict:
    body = json.dumps({"query": query, "variables": variables or {}}).encode()
    headers = {"content-type": "application/json"}
    if auth:
        bearer = os.environ.get("TENOR_BEARER", "").strip()
        cookie = os.environ.get("TENOR_COOKIE", "").strip()
        if bearer:
            headers["authorization"] = (
                f"Bearer {bearer}" if not bearer.lower().startswith("bearer ") else bearer
            )
        if cookie:
            headers["cookie"] = cookie
        if not bearer and not cookie:
            raise SystemExit("Need TENOR_BEARER or TENOR_COOKIE for authenticated mutation")
    req = urllib.request.Request(API, data=body, headers=headers, method="POST")
    with urllib.request.urlopen(req, timeout=45) as resp:
        return json.loads(resp.read().decode())


def cast_call(to: str, sig: str, *args: str) -> str:
    cmd = ["cast", "call", to, sig, *args, "--rpc-url", BASE_RPC]
    return subprocess.check_output(cmd, text=True).strip()


def fortress_check() -> dict:
    """Live true-RSS inventory — never fire Elepan."""
    out: dict = {"collateral": "TRUE_RSS", "elepanDenylist": ELEPAN}
    try:
        rss = int(cast_call(RSS, "balanceOf(address)(uint256)", HOT).split()[0])
        out["hotRss"] = rss / 1e18
        out["rssEnoughFor500kAt70pct"] = rss >= 750_000 * 10**18  # ~714k @70%; buffer
    except Exception as e:
        out["hotRssError"] = str(e)
    try:
        ele = int(cast_call(ELEPAN, "balanceOf(address)(uint256)", HOT).split()[0])
        out["elepanHotUntouched"] = ele / 1e8
    except Exception as e:
        out["elepanError"] = str(e)
    try:
        r = gql(
            """query($a:Address!,$c:Int){
              tokenByAddress(address:$a, chainId:$c){
                address symbol decimals whitelisted
              }
            }""",
            {"a": RSS, "c": 8453},
        )
        out["tenorRssToken"] = r.get("data", {}).get("tokenByAddress")
    except Exception as e:
        out["tenorRssTokenError"] = str(e)
    return out


def orgs() -> list[dict]:
    data = gql("{ organizations { items { id name type } } }")
    return data["data"]["organizations"]["items"]


def build_inquiry(broadcast_all: bool, deadline: int) -> dict:
    select_all = bool(broadcast_all)
    return {
        "buy": False,
        "taker": HOT,
        "assets": ASK,
        "minDuration": 604800,
        "maxDuration": 2592000,
        "deadline": str(deadline),
        "loanTokenAddress": USDC,
        "chainId": 8453,
        "collaterals": [
            {
                "token": RSS,
                "oracle": ORACLE,
                "lltv": LLTV,
                "liquidationCursor": LIQ_CURSOR_MID,
            }
        ],
        "allowedOrganizationIds": [] if select_all else [ARMITAGE],
        "selectAll": select_all,
    }


def mutation_payload(inquiry: dict) -> dict:
    return {
        "query": """
mutation($walletAddress: Address!, $quoteInquiry: CreateQuoteInquiryDto!) {
  createQuoteInquiry(walletAddress: $walletAddress, quoteInquiry: $quoteInquiry) {
    quoteInquiry {
      id
      status
      assets
      deadline
      minDuration
      maxDuration
      loanToken { address symbol }
      collaterals { token oracle lltv liquidationCursor }
    }
  }
}
""",
        "variables": {"walletAddress": HOT, "quoteInquiry": inquiry},
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--fire", action="store_true")
    ap.add_argument("--print-only", action="store_true")
    ap.add_argument("--broadcast-all", action="store_true")
    ap.add_argument("--deadline-days", type=int, default=7)
    args = ap.parse_args()
    if not args.fire and not args.print_only:
        args.print_only = True

    deadline = int(time.time()) + args.deadline_days * 86400
    fortress = fortress_check()
    inquiry = build_inquiry(args.broadcast_all, deadline)
    payload = mutation_payload(inquiry)

    # Hard denylist — never allow Elepan in collateral list
    for c in inquiry["collaterals"]:
        if c["token"].lower() == ELEPAN.lower():
            raise SystemExit("ELEPAN_DENYLIST — abort")

    print("=== FORTRESS (TRUE RSS) ===")
    print(json.dumps(fortress, indent=2))
    print("=== RFQ TARGET ===")
    print("Armitage:", ARMITAGE, "| app:", APP_OTC)
    print(f"Ask: ${ASK_HUMAN:,} USDC | Collateral: TRUE RSS", RSS)
    print("Oracle:", ORACLE, "| LLTV 77%")
    print("Landing (post-fill route):", LANDING)
    print("Elepan denylist:", ELEPAN)
    print("=== createQuoteInquiry DTO ===")
    print(json.dumps(inquiry, indent=2))

    out_path = Path("/tmp/tenor_rfq_500k_rss_payload.json")
    out_path.write_text(json.dumps(payload, indent=2))
    PACKET.write_text(
        json.dumps(
            {
                "plan": "Option C Tenor RFQ $500k vs TRUE RSS",
                "askUsdc": ASK_HUMAN,
                "askRaw": ASK,
                "collateral": RSS,
                "oracle": ORACLE,
                "lltv": LLTV,
                "hot": HOT,
                "landing": LANDING,
                "elepanDenylist": ELEPAN,
                "armitage": ARMITAGE,
                "app": APP_OTC,
                "broadcastAll": args.broadcast_all,
                "inquiry": inquiry,
                "fortress": fortress,
            },
            indent=2,
        )
        + "\n"
    )
    print("Wrote", out_path)
    print("Wrote", PACKET)

    if args.fire:
        try:
            res = gql(payload["query"], payload["variables"], auth=True)
        except urllib.error.HTTPError as e:
            print("HTTP", e.code, e.read().decode()[:800], file=sys.stderr)
            return 1
        print("=== RESPONSE ===")
        print(json.dumps(res, indent=2))
        if res.get("errors"):
            return 1
        qid = (
            res.get("data", {})
            .get("createQuoteInquiry", {})
            .get("quoteInquiry", {})
            .get("id")
        )
        if qid:
            print("INQUIRY_ID", qid)
            print(
                f"Watch: python3 king-pod/script/WatchTenorRfq.py --inquiry-id {qid} --poll"
            )
        return 0

    print("Not fired (print-only). Re-run with --fire + TENOR_BEARER.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
