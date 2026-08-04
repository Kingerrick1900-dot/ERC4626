#!/usr/bin/env python3
"""Watch Tenor RFQ inbox / matching offers for a quote inquiry.

Usage:
  python3 WatchTenorRfq.py --list-orgs
  TENOR_BEARER=... python3 WatchTenorRfq.py --wallet 0x6708... --poll
  TENOR_BEARER=... python3 WatchTenorRfq.py --inquiry-id <uuid>
"""
from __future__ import annotations

import argparse
import json
import os
import time
import urllib.request

API = "https://api.tenor.finance/graphql"
HOT = "0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1"
ARMITAGE = "123cf521-4b9e-4b58-9335-d6d0b35f8b95"


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
            raise SystemExit("Need TENOR_BEARER or TENOR_COOKIE")
    req = urllib.request.Request(API, data=body, headers=headers, method="POST")
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode())


def list_orgs() -> None:
    data = gql("{ organizations { items { id name type websiteUrl } } }")
    for o in data["data"]["organizations"]["items"]:
        mark = " PRIMARY" if o["id"] == ARMITAGE else ""
        print(f"{o['id']}  {o['name']:28}  {o['type']:8}{mark}")


def offers_for_inquiry(inquiry_id: str, wallet: str = HOT) -> dict:
    q = """
    query($w: Address!, $id: String!) {
      offersForInquiry(walletAddress: $w, quoteInquiryId: $id) {
        items {
          id
          rate
          maxAssets
          buy
          loanToken { address symbol }
          collaterals { token oracle lltv }
          organization { name }
        }
      }
    }
    """
    return gql(q, {"w": wallet, "id": inquiry_id}, auth=True)


def user_inquiries(wallet: str) -> dict:
    q = """
    query($wallet: Address!) {
      userQuoteInquiries(walletAddress: $wallet) {
        items {
          id
          status
          assets
          deadline
          loanToken { symbol address }
        }
      }
    }
    """
    return gql(q, {"wallet": wallet}, auth=True)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--list-orgs", action="store_true")
    ap.add_argument("--inquiry-id")
    ap.add_argument("--wallet", default=HOT)
    ap.add_argument("--poll", action="store_true")
    ap.add_argument("--interval", type=int, default=60)
    args = ap.parse_args()

    if args.list_orgs:
        list_orgs()
        return 0

    if args.inquiry_id:
        while True:
            try:
                res = offers_for_inquiry(args.inquiry_id, args.wallet)
                print(json.dumps(res, indent=2))
                items = (
                    res.get("data", {})
                    .get("offersForInquiry", {})
                    .get("items")
                    or []
                )
                if items:
                    print(f"OFFERS={len(items)} — review on https://app.tenor.finance/otc and accept")
                    if not args.poll:
                        return 0
            except Exception as e:
                print("ERR", e)
            if not args.poll:
                return 1
            time.sleep(args.interval)

    # default: list inquiries for wallet (auth required)
    try:
        res = user_inquiries(args.wallet)
        print(json.dumps(res, indent=2))
        if args.poll:
            while True:
                time.sleep(args.interval)
                res = user_inquiries(args.wallet)
                print(json.dumps(res, indent=2))
    except Exception as e:
        print("Auth required to list userQuoteInquiries:", e)
        print("Pass TENOR_BEARER from app.tenor.finance session.")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
