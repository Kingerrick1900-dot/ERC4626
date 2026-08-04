#!/usr/bin/env python3
"""Do the impossible — max open USDC seed + DEX extract + eUSD to Landing."""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = "script/FireImpossibleUsdc.s.sol:FireImpossibleUsdc"
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
    ap.add_argument("--mode", choices=["arm", "extract", "eusd", "all", "status"], default="all")
    ap.add_argument("--machine", default="")
    ap.add_argument("--extra-escrow", default=str(3_000_000 * 10**18))
    ap.add_argument("--sweet-bps", default="2000")
    ap.add_argument("--eusd-amt", default=str(700_000 * 10**18))
    ap.add_argument("--rss-sell", default=str(100_000 * 10**18))
    args = ap.parse_args()
    if not args.fire and not args.dry:
        args.dry = True
    load_pk()
    env = os.environ.copy()
    env["FIRE"] = "1" if args.fire else "0"
    env["MODE"] = "arm" if args.mode == "status" else args.mode
    if args.mode == "status":
        env["FIRE"] = "0"
    env["EXTRA_ESCROW_RSS"] = args.extra_escrow
    env["SWEET_BPS"] = args.sweet_bps
    env["EUSD_AMT"] = args.eusd_amt
    env["RSS_SELL"] = args.rss_sell
    if args.machine:
        env["MACHINE"] = args.machine
    if args.fire and not env.get("PRIVATE_KEY"):
        print("NEED PRIVATE_KEY", file=sys.stderr)
        return 1
    cmd = ["forge", "script", SCRIPT, "--rpc-url", RPC, "-vv"]
    if args.fire:
        cmd += ["--broadcast", "--slow"]
    print("EXEC", " ".join(cmd), "MODE", env["MODE"], flush=True)
    return subprocess.run(cmd, cwd=str(ROOT), env=env).returncode


if __name__ == "__main__":
    raise SystemExit(main())
