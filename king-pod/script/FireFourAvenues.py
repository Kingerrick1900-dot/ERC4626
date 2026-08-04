#!/usr/bin/env python3
"""Status of the four live USDC avenues — escrow is not among them.

  python3 FireFourAvenues.py
  python3 FireFourAvenues.py --watch   # then ScanAllRails + SucceedWatch hints
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

RPC = os.environ.get("BASE_RPC") or os.environ.get("BASE_RPC_URL") or "https://mainnet.base.org"
HOT = "0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1"
LANDING = "0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357"
USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
EUSD = "0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a"
CREDIT = "0x20B1513a137b9CB166E2cC15c405e842278E7D1A"
GATE = "0xab2856626BBd8E6fba9dB93783029eB973E8427F"
COMP_P2 = "0xA247c1d0Ad4E7690764E456E5d8d315bA2912468"
PSM = "0xfFEd7981f924Edc652E9b767aCa601505dfa4977"
MORPHO = "0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb"
PA = "0xA090dD1a701408Df1d4d0B85b716c87565f90467"
YRSS = "0xF80C0529bD94C773844E459853CD91B9263dD525"
RSS_MARKET = "0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794"
FOREIGN = [
    ("Gauntlet", "0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61"),
    ("SteakPrime", "0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2"),
    ("SteakUSDC", "0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183"),
    ("SteakHY", "0xBEEFA7B88064FeEF0cEe02AAeBBd95D30df3878F"),
]
HERE = Path(__file__).resolve().parent


def cast_num(to: str, sig: str, *args: str) -> int:
    out = subprocess.check_output(
        ["cast", "call", to, sig, *args, "--rpc-url", RPC], text=True
    ).strip()
    return int(out.split()[0], 0)


def cast_bool(to: str, sig: str, *args: str) -> bool:
    out = subprocess.check_output(
        ["cast", "call", to, sig, *args, "--rpc-url", RPC], text=True
    ).strip().lower()
    return out.startswith("true")


def main() -> int:
    proven = cast_bool(GATE, "isProven(address)(bool)", HOT)
    max_ask = cast_num(COMP_P2, "maxAsk()(uint256)")
    credit = cast_num(USDC, "balanceOf(address)(uint256)", CREDIT)
    hot_usdc = cast_num(USDC, "balanceOf(address)(uint256)", HOT)
    land_usdc = cast_num(USDC, "balanceOf(address)(uint256)", LANDING)
    op = cast_bool(CREDIT, "operator(address)(bool)", COMP_P2)
    hot_eusd = cast_num(EUSD, "balanceOf(address)(uint256)", HOT)
    land_eusd = cast_num(EUSD, "balanceOf(address)(uint256)", LANDING)
    psm_usdc = cast_num(USDC, "balanceOf(address)(uint256)", PSM)
    mkt = subprocess.check_output(
        [
            "cast",
            "call",
            MORPHO,
            "market(bytes32)(uint128,uint128,uint128,uint128,uint128,uint128)",
            RSS_MARKET,
            "--rpc-url",
            RPC,
        ],
        text=True,
    ).strip().splitlines()
    supply = int(mkt[0].split()[0], 0)
    borrow = int(mkt[2].split()[0], 0)
    idle = max(supply - borrow, 0)
    pa = []
    max_foreign = 0
    for name, vault in FOREIGN:
        caps = subprocess.check_output(
            [
                "cast",
                "call",
                PA,
                "flowCaps(address,bytes32)(uint128,uint128)",
                vault,
                RSS_MARKET,
                "--rpc-url",
                RPC,
            ],
            text=True,
        ).strip().splitlines()
        mi = int(caps[0].split()[0], 0)
        max_foreign = max(max_foreign, mi)
        pa.append({"name": name, "maxIn": mi / 1e6})
    yrss_wd = cast_num(YRSS, "maxWithdraw(address)(uint256)", HOT)

    a1_green = proven and op and (hot_usdc > 0 or credit > 0) and max_ask > 0
    a2_note = "refresh TENOR_BEARER if Unauthorized; inquiries live"
    a3_green = psm_usdc >= 100_000 * 10**6  # redeemable depth floor
    a4_green = idle >= 100_000 * 10**6 or max_foreign >= 100_000 * 10**6

    board = {
        "doctrine": "escrow_is_theater",
        "landing_usdc": land_usdc / 1e6,
        "avenues": {
            "1_bound_completer": {
                "live_machine": True,
                "proven": proven,
                "operator": op,
                "maxAsk_usdc": max_ask / 1e6,
                "credit_usdc": credit / 1e6,
                "hot_usdc": hot_usdc / 1e6,
                "green": a1_green,
                "fire": "FireFundBoundCredit.py --watch --fire | SucceedWatch.py --poll --auto-complete",
            },
            "2_tenor_rfq": {
                "live_inquiries": True,
                "armitage": "7e35d157-3dfe-40bc-81e5-e0841037976d",
                "broadcast": "caaa6250-04c3-4b9a-98e1-64531f67be97",
                "note": a2_note,
                "fire": "WatchTenorRfq.py --poll | SucceedWatch.py --poll",
            },
            "3_eusd_unlock": {
                "hot_eusd": hot_eusd / 1e18,
                "landing_eusd": land_eusd / 1e18,
                "psm_usdc_reserve": psm_usdc / 1e6,
                "green": a3_green,
                "block": "PSM/DEX depth — inventory already held",
                "fire": "capitalize PSM 0xfFEd…4977 then redeem → Completer",
            },
            "4_morpho_pa_bundler3": {
                "morpho_idle_usdc": idle / 1e6,
                "foreign_pa": pa,
                "yrss_maxWithdraw_usdc": yrss_wd / 1e6,
                "green": a4_green,
                "fire": "ScanAllRails.py --auto-fire | watch_maxin_fire.py",
            },
        },
        "not_an_avenue": "permissionless RSS escrow fill",
    }
    print(json.dumps(board, indent=2))
    print(
        "\nChief: run SucceedWatch + ScanAllRails in parallel. First cash wins.",
        file=sys.stderr,
    )
    if "--watch" in sys.argv:
        print("HINT: python3", HERE / "SucceedWatch.py", "--poll --auto-complete", file=sys.stderr)
        print("HINT: python3", HERE / "ScanAllRails.py", "--poll --auto-fire", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
