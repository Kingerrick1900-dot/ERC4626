#!/usr/bin/env python3
"""Step 1 gate: is Option C lender liquidity live on the RSS Morpho market?

Pass if idle USDC >= ask (default $700k). Optional: note Tenor offer path separately.

Usage:
  python3 CheckRssLenderCommitment.py
  python3 CheckRssLenderCommitment.py --ask 600000
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys

HOT = "0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1"
LANDING = "0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357"
RSS = "0x7a305D07B537359cf468eAea9bb176E5308bC337"
ELEPAN = "0x50639C42E2FFDEC4F68FB468968a55b3Af944583"
USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
MORPHO = "0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb"
RSS_MARKET = "0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794"
RPC = os.environ.get("BASE_RPC") or os.environ.get("BASE_RPC_URL") or "https://mainnet.base.org"


def cast_call(to: str, sig: str, *args: str) -> list[int]:
    out = subprocess.check_output(
        ["cast", "call", to, sig, *args, "--rpc-url", RPC], text=True
    ).strip()
    return [int(line.split()[0]) for line in out.splitlines()]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ask", type=int, default=700_000, help="USDC ask (human)")
    args = ap.parse_args()
    ask_raw = args.ask * 10**6
    if args.ask < 600_000 or args.ask > 700_000:
        print("WARN: plan band is $600k–$700k", file=sys.stderr)

    rss = cast_call(RSS, "balanceOf(address)(uint256)", HOT)[0]
    ele = cast_call(ELEPAN, "balanceOf(address)(uint256)", HOT)[0]
    landing = cast_call(USDC, "balanceOf(address)(uint256)", LANDING)[0]
    mkt = cast_call(
        MORPHO,
        "market(bytes32)(uint128,uint128,uint128,uint128,uint128,uint128)",
        RSS_MARKET,
    )
    pos = cast_call(
        MORPHO, "position(bytes32,address)(uint256,uint128,uint128)", RSS_MARKET, HOT
    )
    supply, borrow = mkt[0], mkt[2]
    idle = supply - borrow if supply > borrow else 0

    step2_ok = rss >= 15_000_000 * 10**18
    step1_ok = idle >= ask_raw
    loan_clean = pos[1] == 0

    report = {
        "step1_lender_idle_ok": step1_ok,
        "step2_rss_on_hot_ok": step2_ok,
        "ask_usdc": args.ask,
        "idle_usdc": idle / 1e6,
        "supply_usdc": supply / 1e6,
        "borrow_usdc": borrow / 1e6,
        "rss_hot": rss / 1e18,
        "elepan_hot_untouched": ele / 1e8,
        "hot_morpho_borrow_shares": pos[1],
        "hot_morpho_collateral_rss": pos[2] / 1e18,
        "landing_usdc": landing / 1e6,
        "loan_clean": loan_clean,
        "step3_armed": step1_ok and step2_ok and loan_clean,
        "desks": ["Armitage/Wintermute", "Wintermute OTC", "DWF"],
        "fire_when_ready": (
            "FIRE=1 ASK_USDC=%d COLL_RSS=1200000000000000000000000 "
            "forge script king-pod/script/FireRssOptionCAtomicSeed.s.sol:FireRssOptionCAtomicSeed "
            "--rpc-url $BASE_RPC --broadcast --slow" % ask_raw
        ),
    }
    print(json.dumps(report, indent=2))
    if not step1_ok:
        print(
            "STEP1 FAIL: lender idle short — desk must supply USDC into RSS market "
            "(or present accept-ready Tenor lend offer) before Step 3.",
            file=sys.stderr,
        )
        return 2
    if not step2_ok:
        print("STEP2 FAIL: need ≥15M RSS on hot", file=sys.stderr)
        return 3
    print("STEP1+2 PASS — Step 3 armed (King FIRE=1 only)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
