#!/usr/bin/env python3
"""Kingdom rails scanner — DEX Flash Router primary (NO Morpho borrow-queue).

King order 2026-08-04: stop querying Morpho idle/PA borrow queue.
Primary extract = CrownAtomicDexFlashRouter (Aerodrome RSS→USDC → Landing).

Usage:
  python3 ScanAllRails.py
  python3 ScanAllRails.py --auto-fire
  python3 ScanAllRails.py --poll --interval 60 --auto-fire
  DEX_DUST_OK=1 python3 ScanAllRails.py --auto-fire   # fire depth-limited extract
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

HERE = Path(__file__).resolve().parent

HOT = "0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1"
LANDING = "0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357"
RSS = "0x7a305D07B537359cf468eAea9bb176E5308bC337"
ELEPAN = "0x50639C42E2FFDEC4F68FB468968a55b3Af944583"
USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
AERO = "0x2C4F14744B8b3D087b768D0764d983Acb46d537a"
AERO_ROUTER = "0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43"
AERO_FACTORY = "0x420DD381b31aEf6683db6B902084cB0FFECe40Da"
CREDIT = "0x20B1513a137b9CB166E2cC15c405e842278E7D1A"
GATE = "0xab2856626BBd8E6fba9dB93783029eB973E8427F"
RPC = os.environ.get("BASE_RPC") or os.environ.get("BASE_RPC_URL") or "https://mainnet.base.org"
TENOR_API = "https://api.tenor.finance/graphql"
INQUIRIES = [
    ("Armitage", "7e35d157-3dfe-40bc-81e5-e0841037976d"),
    ("Broadcast", "caaa6250-04c3-4b9a-98e1-64531f67be97"),
]
ROUTER_ENV = os.environ.get("DEX_ROUTER", "").strip()


def cast_nums(to: str, sig: str, *args: str) -> list[int]:
    out = subprocess.check_output(
        ["cast", "call", to, sig, *args, "--rpc-url", RPC], text=True
    ).strip()
    nums: list[int] = []
    for line in out.splitlines():
        tok = line.split()[0]
        try:
            nums.append(int(tok, 0))
        except ValueError:
            pass
    return nums


def cast_bool(to: str, sig: str, *args: str) -> bool:
    out = (
        subprocess.check_output(
            ["cast", "call", to, sig, *args, "--rpc-url", RPC], text=True
        )
        .strip()
        .lower()
    )
    return out.startswith("true")


def tenor_offers(inquiry_id: str) -> list[dict]:
    bearer = os.environ.get("TENOR_BEARER", "").strip()
    if not bearer:
        return []
    auth = bearer if bearer.lower().startswith("bearer ") else f"Bearer {bearer}"
    q = """
    query($w: Address!, $id: String!) {
      offersForInquiry(walletAddress: $w, quoteInquiryId: $id) {
        items { id rate maxAssets organization { name } }
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


def quote_aero(rss_in: int) -> int:
    """getAmountsOut via Aerodrome router Route(from,to,stable,factory)."""
    # cast call getAmountsOut(uint256,(address,address,bool,address)[])
    route = f"[({RSS},{USDC},false,{AERO_FACTORY})]"
    try:
        out = subprocess.check_output(
            [
                "cast",
                "call",
                AERO_ROUTER,
                "getAmountsOut(uint256,(address,address,bool,address)[])(uint256[])",
                str(rss_in),
                route,
                "--rpc-url",
                RPC,
            ],
            text=True,
        ).strip()
        # last number in output
        nums = []
        for line in out.replace("[", " ").replace("]", " ").replace(",", " ").split():
            try:
                nums.append(int(line, 0))
            except ValueError:
                pass
        return nums[-1] if nums else 0
    except Exception:
        return 0


def scan(ask_usdc: int) -> dict:
    ask_raw = ask_usdc * 10**6
    dust_ok = os.environ.get("DEX_DUST_OK", "").strip() in ("1", "true", "YES")
    fires: list[str] = []
    auto: list[dict] = []

    rss_hot = cast_nums(RSS, "balanceOf(address)(uint256)", HOT)[0]
    ele = cast_nums(ELEPAN, "balanceOf(address)(uint256)", HOT)[0]
    landing = cast_nums(USDC, "balanceOf(address)(uint256)", LANDING)[0]
    aero_usdc = cast_nums(USDC, "balanceOf(address)(uint256)", AERO)[0]
    aero_rss = cast_nums(RSS, "balanceOf(address)(uint256)", AERO)[0]
    credit_usdc = cast_nums(USDC, "balanceOf(address)(uint256)", CREDIT)[0]
    proven = cast_bool(GATE, "isProven(address)(bool)", HOT)

    # DEX quote for a probe size (1k RSS) + max depth extract
    probe_rss = 1000 * 10**18
    probe_out = quote_aero(probe_rss) if rss_hot >= probe_rss else 0

    # Primary: DEX depth ≥ ask → full extract OR dust mode
    if aero_usdc >= ask_raw and rss_hot > 0:
        fires.append(
            f"R10_DEX_FLASH reserve={aero_usdc/1e6:.2f} USDC ≥ ask → AtomicDexFlashRouter extract/unwind"
        )
        auto.append(
            {
                "rail": "R10",
                "executor": "dex_flash",
                "mode": "extract",
                "ask": ask_usdc,
                "aero_usdc": aero_usdc,
            }
        )
    elif dust_ok and aero_usdc > 0 and rss_hot > 0:
        # Depth-limited: sell RSS for almost all pool USDC (leave $0.01)
        fires.append(
            f"R10_DEX_DUST reserve={aero_usdc/1e6:.6f} USDC — DEX_DUST_OK extract (not $ask)"
        )
        auto.append(
            {
                "rail": "R10",
                "executor": "dex_flash",
                "mode": "extract",
                "dust": True,
                "rss_in": str(min(rss_hot, 10_000 * 10**18)),
                "min_usdc": str(max(aero_usdc // 2, 1)),  # take half reserve minOut
            }
        )

    # Tenor still watched (not Morpho borrow queue)
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
            if assets >= ask_raw:
                fires.append(f"R1_TENOR {label} offer {off.get('id')} — ACCEPT → Landing")
                auto.append(
                    {
                        "rail": "R1",
                        "executor": "tenor_accept",
                        "offer": off.get("id"),
                        "inquiry": qid,
                    }
                )

    if proven and credit_usdc >= ask_raw:
        fires.append("R5_BOUND_CREDIT funded — Completer/AutoDraw (secondary)")

    report = {
        "primary": "ATOMIC_DEX_FLASH_ROUTER",
        "morpho_borrow_queue": "DISABLED",
        "ask_usdc": ask_usdc,
        "landing_usdc": landing / 1e6,
        "rss_hot": rss_hot / 1e18,
        "elepan_untouched": ele / 1e8,
        "dex": {
            "pool": AERO,
            "usdc_reserve": aero_usdc / 1e6,
            "rss_reserve": aero_rss / 1e18,
            "probe_1000rss_usdc_out": probe_out / 1e6,
            "router": ROUTER_ENV or "(deploy via FireDexFlashRouter)",
        },
        "bound_credit_usdc": credit_usdc / 1e6,
        "bound_proven": proven,
        "tenor": tenor,
        "FIRE": fires,
        "auto_candidates": auto,
        "any_fire": bool(fires),
    }
    return report


def auto_fire_first(report: dict) -> int:
    cands = report.get("auto_candidates") or []
    if not cands:
        print("AUTO_FIRE: no green DEX/Tenor candidates", file=sys.stderr)
        return 2

    chosen = None
    for c in cands:
        if c.get("executor") == "dex_flash":
            chosen = c
            break
    if not chosen:
        print(
            "AUTO_FIRE: first green is non-DEX:",
            json.dumps(cands[0]),
            file=sys.stderr,
        )
        return 3

    # Ensure router deployed: if no DEX_ROUTER, deploy first
    router = ROUTER_ENV
    env = os.environ.copy()
    if not router:
        print("AUTO_FIRE: deploying CrownAtomicDexFlashRouter…", file=sys.stderr)
        r = subprocess.run(
            [sys.executable, str(HERE / "FireDexFlashRouter.py"), "--fire", "--mode", "deploy"],
            env=env,
            cwd=str(HERE.parent),
            capture_output=True,
            text=True,
        )
        print(r.stdout[-2000:] if r.stdout else "", file=sys.stderr)
        print(r.stderr[-1000:] if r.stderr else "", file=sys.stderr)
        if r.returncode != 0:
            return r.returncode
        # parse DEPLOYED
        for line in (r.stdout or "").splitlines():
            if "DEPLOYED" in line:
                parts = line.split()
                router = parts[-1]
                break
        if not router:
            print("AUTO_FIRE: could not parse DEPLOYED address", file=sys.stderr)
            return 4
        print("AUTO_FIRE ROUTER", router, file=sys.stderr)

    cmd = [
        sys.executable,
        str(HERE / "FireDexFlashRouter.py"),
        "--fire",
        "--mode",
        "extract",
        "--router",
        router,
    ]
    if chosen.get("dust"):
        cmd += ["--rss-in", chosen["rss_in"], "--min-usdc", chosen["min_usdc"]]
    else:
        # size rss for ask via iterative — for full ask use large RSS; router Depth-gates
        cmd += ["--rss-in", str(int(2_000_000 * 1e18)), "--min-usdc", str(int(chosen["ask"] * 1e6))]

    print("AUTO_FIRE CMD:", " ".join(cmd), file=sys.stderr)
    return subprocess.run(cmd, env=env).returncode


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--poll", action="store_true")
    ap.add_argument("--interval", type=int, default=60)
    ap.add_argument("--ask", type=int, default=int(os.environ.get("ASK_USDC", "500000")))
    ap.add_argument("--auto-fire", action="store_true")
    args = ap.parse_args()

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
            print("=== RAIL(S) GREEN (DEX-primary) ===", file=sys.stderr)
            for f in report["FIRE"]:
                print("FIRE:", f, file=sys.stderr)
            if args.auto_fire:
                code = auto_fire_first(report)
                if not args.poll:
                    return code
                if code == 0:
                    return 0
        else:
            print(
                "No DEX depth for ask yet — Morpho borrow-queue disabled. "
                "Router armed. Set DEX_DUST_OK=1 to extract current pool dust.",
                file=sys.stderr,
            )
            if args.auto_fire and not args.poll:
                return 2
        if not args.poll:
            return 0 if report["any_fire"] else 2
        time.sleep(args.interval)


if __name__ == "__main__":
    raise SystemExit(main())
