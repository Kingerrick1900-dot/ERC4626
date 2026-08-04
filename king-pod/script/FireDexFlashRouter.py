#!/usr/bin/env python3
"""Atomic DEX Flash Router — extract Landing USDC from Base Aerodrome (no Morpho borrow queue).

Usage:
  python3 FireDexFlashRouter.py --dry
  python3 FireDexFlashRouter.py --fire --mode deploy
  python3 FireDexFlashRouter.py --fire --mode extract --rss-in 1000e18 --min-usdc 1
  python3 FireDexFlashRouter.py --fire --mode unwind   # reverts if DEX depth < debt
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = "script/FireDexFlashRouter.s.sol:FireDexFlashRouter"
RPC = os.environ.get("BASE_RPC") or os.environ.get("BASE_RPC_URL") or "https://mainnet.base.org"


def load_pk() -> None:
    envp = Path("/tmp/cursor/hot_pk.env")
    if envp.is_file():
        for line in envp.read_text().splitlines():
            if "=" in line and not line.strip().startswith("#"):
                k, v = line.strip().split("=", 1)
                os.environ.setdefault(k, v.strip().strip('"').strip("'"))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--fire", action="store_true")
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("--mode", choices=["deploy", "extract", "unwind"], default="deploy")
    ap.add_argument("--router", default="")
    ap.add_argument("--rss-in", default="1000000000000000000000")  # 1000 RSS
    ap.add_argument("--min-usdc", default="1")
    ap.add_argument("--min-landing", default="0")
    ap.add_argument("--rss-sell-cap", default="0")
    args = ap.parse_args()
    if not args.fire and not args.dry:
        args.dry = True

    load_pk()
    env = os.environ.copy()
    env["FIRE"] = "1" if args.fire else "0"
    env["MODE"] = args.mode
    env["RSS_IN"] = args.rss_in
    env["MIN_USDC"] = args.min_usdc
    env["MIN_LANDING"] = args.min_landing
    env["RSS_SELL_CAP"] = args.rss_sell_cap
    if args.router:
        env["ROUTER"] = args.router

    if args.fire and not env.get("PRIVATE_KEY"):
        print("NEED PRIVATE_KEY", file=sys.stderr)
        return 1

    cmd = ["forge", "script", SCRIPT, "--rpc-url", RPC, "-vv"]
    if args.fire:
        cmd += ["--broadcast", "--slow"]

    print("EXEC", " ".join(cmd), "MODE", args.mode, flush=True)
    return subprocess.run(cmd, cwd=str(ROOT), env=env).returncode


if __name__ == "__main__":
    raise SystemExit(main())
