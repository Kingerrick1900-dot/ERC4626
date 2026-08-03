#!/usr/bin/env python3
"""Code-first Tenor OTC RFQ: $700k USDC borrow vs ELE → Armitage (Wintermute).

Primary path: GraphQL createQuoteInquiry to Armitage org.
Auth: Tenor requires a logged-in wallet session (Unauthorized without it).
  Pass TENOR_BEARER=<jwt> or TENOR_COOKIE=<cookie> from app.tenor.finance after connect,
  OR run --print-only and fire via UI with this exact packet.

Usage:
  python3 FireTenorArmitageRfq.py --print-only
  TENOR_BEARER=... python3 FireTenorArmitageRfq.py --fire
  TENOR_BEARER=... python3 FireTenorArmitageRfq.py --fire --broadcast-all
"""
from __future__ import annotations

import argparse
import json
import os
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
ELE = "0x50639C42E2FFDEC4F68FB468968a55b3Af944583"
ORACLE = "0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19"
LLTV = "770000000000000000"
ASK = "700000000000"  # $700k USDC 6dp
ARMITAGE = "123cf521-4b9e-4b58-9335-d6d0b35f8b95"
# Tenor/Morpho-allowed liquidation cursors (WAD fractions): LOW=0.25 MID=0.30 HIGH=0.50
LIQ_CURSOR_MID = "300000000000000000"
BASE_RPC = os.environ.get("BASE_RPC") or os.environ.get("BASE_RPC_URL") or "https://mainnet.base.org"
PACKET = Path(__file__).resolve().parents[1] / "deployments" / "tenor-armitage-rfq-700k.json"


def gql(query: str, variables: dict | None = None, auth: bool = False) -> dict:
    body = json.dumps({"query": query, "variables": variables or {}}).encode()
    headers = {"content-type": "application/json"}
    if auth:
        bearer = os.environ.get("TENOR_BEARER", "").strip()
        cookie = os.environ.get("TENOR_COOKIE", "").strip()
        if bearer:
            headers["authorization"] = f"Bearer {bearer}" if not bearer.lower().startswith("bearer ") else bearer
        if cookie:
            headers["cookie"] = cookie
        if not bearer and not cookie:
            raise SystemExit("Need TENOR_BEARER or TENOR_COOKIE for authenticated mutation")
    req = urllib.request.Request(API, data=body, headers=headers, method="POST")
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode())


def cast_call(sig: str, *args: str) -> str:
    import subprocess

    cmd = ["cast", "call", *args, sig, "--rpc-url", BASE_RPC] if False else None
    # cast call <to> <sig> [args...]
    to = args[0]
    rest = list(args[1:])
    cmd = ["cast", "call", to, sig, *rest, "--rpc-url", BASE_RPC]
    return subprocess.check_output(cmd, text=True).strip()


def fortress_check() -> dict:
    """Live ELE / proof sanity — never fire blind."""
    out: dict = {}
    try:
        ele = int(cast_call("balanceOf(address)(uint256)", ELE, HOT).split()[0])
        out["hotEle"] = ele / 1e8
    except Exception as e:
        out["hotEleError"] = str(e)
    try:
        gate = "0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30"
        proven = cast_call("isProven(address)(bool)", gate, HOT).lower()
        out["elepanProven"] = proven.startswith("true")
    except Exception as e:
        out["elepanProvenError"] = str(e)
    try:
        gate = "0xab2856626BBd8E6fba9dB93783029eB973E8427F"
        proven = cast_call("isProven(address)(bool)", gate, HOT).lower()
        out["boundProven"] = proven.startswith("true")
    except Exception as e:
        out["boundProvenError"] = str(e)
    return out


def orgs() -> list[dict]:
    data = gql("{ organizations { items { id name type } } }")
    return data["data"]["organizations"]["items"]


def build_inquiry(broadcast_all: bool, deadline: int) -> dict:
    allowed = [ARMITAGE]
    select_all = False
    if broadcast_all:
        allowed = [o["id"] for o in orgs() if o.get("type") in ("Curator", "Fund")]
        # still keep Armitage first; selectAll True = all counterparties
        select_all = True
        allowed = [ARMITAGE]  # API: selectAll true ignores list; keep Armitage for logs
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
                "token": ELE,
                "oracle": ORACLE,
                "lltv": LLTV,
                "liquidationCursor": LIQ_CURSOR_MID,
            }
        ],
        "allowedOrganizationIds": [] if select_all else [ARMITAGE],
        "selectAll": select_all,
    }


def mutation_payload(inquiry: dict) -> dict:
    # PartialCollateral.token is Address scalar (not Token object).
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
    ap.add_argument("--fire", action="store_true", help="POST createQuoteInquiry (needs TENOR_BEARER/COOKIE)")
    ap.add_argument("--print-only", action="store_true", help="Print packet + curl only")
    ap.add_argument("--broadcast-all", action="store_true", help="RFQ to all Tenor curators/funds")
    ap.add_argument("--deadline-days", type=int, default=7)
    args = ap.parse_args()
    if not args.fire and not args.print_only:
        args.print_only = True

    deadline = int(time.time()) + args.deadline_days * 86400
    fortress = fortress_check()
    inquiry = build_inquiry(args.broadcast_all, deadline)
    payload = mutation_payload(inquiry)

    print("=== FORTRESS ===")
    print(json.dumps(fortress, indent=2))
    print("=== RFQ TARGET ===")
    print("Armitage:", ARMITAGE, "| app:", APP_OTC)
    print("Ask: $700,000 USDC | Collateral: ELE", ELE)
    print("Landing (post-fill route):", LANDING)
    print("=== createQuoteInquiry DTO ===")
    print(json.dumps(inquiry, indent=2))

    out_path = Path("/tmp/tenor_rfq_payload.json")
    out_path.write_text(json.dumps(payload, indent=2))
    print("Wrote", out_path)

    curl = (
        f"curl -sS '{API}' -H 'content-type: application/json' "
        f"-H \"authorization: Bearer $TENOR_BEARER\" "
        f"--data @{out_path}"
    )
    print("=== CURL (auth required) ===")
    print(curl)
    print("=== UI FALLBACK ===")
    print(f"1) Connect hot {HOT} at {APP_OTC}")
    print("2) Borrow → Request Quote")
    print("3) Borrow 700000 USDC · collateral ELE/RSS 0x5063…4583 · maturity 7–30d")
    print("4) Counterparty: Armitage by Wintermute (primary)")
    print("5) Send request → inbox for matching onchain offers → accept → USDC to hot → route Landing")

    if args.fire:
        try:
            res = gql(payload["query"], payload["variables"], auth=True)
        except urllib.error.HTTPError as e:
            print("HTTP", e.code, e.read().decode()[:500], file=sys.stderr)
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
            print(f"Watch: python3 WatchTenorRfq.py --inquiry-id {qid}")
        return 0

    print("Not fired (print-only). Set TENOR_BEARER from app session and re-run --fire.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
