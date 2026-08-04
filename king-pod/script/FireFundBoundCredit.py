#!/usr/bin/env python3
"""Fund Bound credit → Landing NOW via Completer.complete.

YES — this is the instant seed path once USDC is on hot (or credit already funded):
  completer.complete(amount) = pull USDC → credit.supply → operatorBorrowTo(Landing)
  maxAsk = $490k (70% of $700k proven threshold)

Kingdom liquid USDC is currently ~$0 — script arms and fires when funded.

Usage:
  python3 FireFundBoundCredit.py --dry
  python3 FireFundBoundCredit.py --fire --mode complete --amount 490000
  python3 FireFundBoundCredit.py --fire --mode poke          # if credit already has USDC
  python3 FireFundBoundCredit.py --watch --fire              # poll until hot USDC >= ask
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = "script/FireFundBoundCredit.s.sol:FireFundBoundCredit"
RPC = os.environ.get("BASE_RPC") or os.environ.get("BASE_RPC_URL") or "https://mainnet.base.org"
HOT = "0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1"
USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
CREDIT = "0x20B1513a137b9CB166E2cC15c405e842278E7D1A"


def load_pk() -> None:
    envp = Path("/tmp/cursor/hot_pk.env")
    if envp.is_file():
        for line in envp.read_text().splitlines():
            if "=" in line and not line.strip().startswith("#"):
                k, v = line.strip().split("=", 1)
                os.environ.setdefault(k, v.strip().strip('"').strip("'"))


def usdc_of(addr: str) -> int:
    out = subprocess.check_output(
        ["cast", "call", USDC, "balanceOf(address)(uint256)", addr, "--rpc-url", RPC],
        text=True,
    ).strip()
    return int(out.split()[0])


def run_forge(fire: bool, mode: str, amount_raw: int) -> int:
    load_pk()
    env = os.environ.copy()
    env["FIRE"] = "1" if fire else "0"
    env["MODE"] = mode
    env["AMOUNT"] = str(amount_raw)
    if fire and not env.get("PRIVATE_KEY"):
        print("NEED PRIVATE_KEY", file=sys.stderr)
        return 1
    cmd = ["forge", "script", SCRIPT, "--rpc-url", RPC, "-vv"]
    if fire:
        cmd += ["--broadcast", "--slow"]
    print("EXEC", " ".join(cmd), flush=True)
    return subprocess.run(cmd, cwd=str(ROOT), env=env).returncode


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--fire", action="store_true")
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("--watch", action="store_true", help="Poll until hot/credit USDC >= amount then fire")
    ap.add_argument("--mode", choices=["complete", "supply_draw", "poke"], default="complete")
    ap.add_argument("--amount", type=int, default=490_000, help="USDC human (default 490k maxAsk)")
    ap.add_argument("--interval", type=int, default=30)
    args = ap.parse_args()
    if not args.fire and not args.dry and not args.watch:
        args.dry = True

    amount_raw = args.amount * 10**6

    if args.watch:
        print(
            f"WATCH fund-credit: need hot or credit USDC >= {args.amount} then FIRE mode={args.mode}",
            flush=True,
        )
        while True:
            hot = usdc_of(HOT)
            credit = usdc_of(CREDIT)
            print(f"hot={hot/1e6:.2f} credit={credit/1e6:.2f}", flush=True)
            if args.mode == "poke" and credit > 0:
                return run_forge(True, "poke", amount_raw)
            if hot >= amount_raw:
                return run_forge(True, args.mode, amount_raw)
            time.sleep(args.interval)

    return run_forge(args.fire, args.mode, amount_raw)


if __name__ == "__main__":
    raise SystemExit(main())
