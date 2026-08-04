#!/usr/bin/env python3
"""Permissionless USDC seed — open RSS escrow fill → Landing (no desk wait).

Also: eusd_landing relocates eUSD treasury to Landing.

Usage:
  python3 FirePermissionlessUsdcSeed.py --dry
  python3 FirePermissionlessUsdcSeed.py --fire --mode deploy
  python3 FirePermissionlessUsdcSeed.py --fire --mode eusd_landing --eusd-amt 100000e18
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = "script/FirePermissionlessUsdcSeed.s.sol:FirePermissionlessUsdcSeed"
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
    ap.add_argument("--mode", choices=["deploy", "escrow", "eusd_landing"], default="deploy")
    ap.add_argument("--seed", default="")
    ap.add_argument("--escrow-rss", default=str(2_000_000 * 10**18))
    ap.add_argument("--sweet-bps", default="300")
    ap.add_argument("--eusd-amt", default=str(100_000 * 10**18))
    args = ap.parse_args()
    if not args.fire and not args.dry:
        args.dry = True
    load_pk()
    env = os.environ.copy()
    env["FIRE"] = "1" if args.fire else "0"
    env["MODE"] = args.mode
    env["ESCROW_RSS"] = args.escrow_rss
    env["SWEET_BPS"] = args.sweet_bps
    env["EUSD_AMT"] = args.eusd_amt
    if args.seed:
        env["SEED"] = args.seed
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
