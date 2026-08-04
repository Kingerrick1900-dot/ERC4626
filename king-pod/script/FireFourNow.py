#!/usr/bin/env python3
"""FIRE ALL FOUR — execution only. No dashboard.

  A1 Completer/AutoDraw + A3 PSM/eUSD + A4 Morpho idle → forge FireFourNow
  A2 Tenor true-RSS RFQ → FireTenorRssRfq500k --fire --broadcast-all

  python3 FireFourNow.py --fire
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RPC = os.environ.get("BASE_RPC") or os.environ.get("BASE_RPC_URL") or "https://mainnet.base.org"


def load_env() -> None:
    for p in ("/tmp/cursor/hot_pk.env", "/tmp/cursor/tenor_bearer.env"):
        if os.path.isfile(p):
            for line in open(p):
                if "=" in line and not line.strip().startswith("#"):
                    k, v = line.strip().split("=", 1)
                    os.environ.setdefault(k, v.strip().strip('"').strip("'"))


def main() -> int:
    fire = "--fire" in sys.argv
    load_env()
    if fire and not os.environ.get("PRIVATE_KEY"):
        print("NEED PRIVATE_KEY", file=sys.stderr)
        return 1

    env = os.environ.copy()
    env["FIRE"] = "1" if fire else "0"

    # A1 + A3 + A4 onchain
    cmd = [
        "forge",
        "script",
        "script/FireFourNow.s.sol:FireFourNow",
        "--rpc-url",
        RPC,
        "-vv",
    ]
    if fire:
        cmd += ["--broadcast", "--slow"]
    print("EXEC_ONCHAIN", " ".join(cmd), flush=True)
    r1 = subprocess.run(cmd, cwd=str(ROOT), env=env)

    # A2 Tenor RSS (offchain desk rail)
    tenor = [
        sys.executable,
        str(ROOT / "script" / "FireTenorRssRfq500k.py"),
        "--fire",
        "--broadcast-all",
    ]
    if not fire:
        tenor = [
            sys.executable,
            str(ROOT / "script" / "FireTenorRssRfq500k.py"),
            "--print-only",
        ]
    print("EXEC_TENOR", " ".join(tenor), flush=True)
    r2 = subprocess.run(tenor, cwd=str(ROOT), env=env)

    # A1: only poke when credit has USDC (never broadcast a guaranteed revert)
    if fire:
        credit = subprocess.check_output(
            [
                "cast",
                "call",
                "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
                "balanceOf(address)(uint256)",
                "0x20B1513a137b9CB166E2cC15c405e842278E7D1A",
                "--rpc-url",
                RPC,
            ],
            text=True,
        ).strip()
        credit_raw = int(credit.split()[0], 0)
        if credit_raw > 0:
            fund = [
                sys.executable,
                str(ROOT / "script" / "FireFundBoundCredit.py"),
                "--fire",
                "--mode",
                "poke",
            ]
            print("EXEC_A1_POKE", " ".join(fund), flush=True)
            subprocess.run(fund, cwd=str(ROOT), env=env)
        else:
            print("A1_ARMED maxAsk=490000 credit=0 — matcher/complete when USDC arrives", flush=True)

    print(f"DONE onchain={r1.returncode} tenor={r2.returncode}", flush=True)
    return 0 if r1.returncode == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
