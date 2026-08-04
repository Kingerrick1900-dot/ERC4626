#!/usr/bin/env python3
"""Primary live executor wrapper — Morpho Bundler3 atomic pack → Landing.

Called by ScanAllRails --auto-fire when R2 (Morpho idle) or R3 (PA maxIn) greens.
Does NOT touch Elepan. Does NOT auto-swap Aerodrome (R10).

Usage:
  python3 FireBundler3AtomicPack.py --dry
  FIRE=1 ASK_USDC=500000000000 python3 FireBundler3AtomicPack.py --fire
  python3 FireBundler3AtomicPack.py --fire --pa-vault 0x... --pull-usdc 500000000000
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = "script/FireBundler3AtomicPack.s.sol:FireBundler3AtomicPack"
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
    ap.add_argument("--ask", type=int, default=500_000, help="USDC human")
    ap.add_argument("--coll-rss", type=str, default="800000000000000000000000")
    ap.add_argument("--pa-vault", default="")
    ap.add_argument("--pull-usdc", type=str, default="0")
    args = ap.parse_args()
    if not args.fire and not args.dry:
        args.dry = True

    load_pk()
    if args.fire and not os.environ.get("PRIVATE_KEY"):
        print("NEED PRIVATE_KEY for --fire", file=sys.stderr)
        return 1

    env = os.environ.copy()
    env["ASK_USDC"] = str(args.ask * 10**6)
    env["COLL_RSS"] = args.coll_rss
    env["FIRE"] = "1" if args.fire else "0"
    if args.pa_vault:
        env["PA_VAULT"] = args.pa_vault
        env["PULL_USDC"] = args.pull_usdc

    cmd = [
        "forge",
        "script",
        SCRIPT,
        "--rpc-url",
        RPC,
        "-vv",
    ]
    if args.fire:
        cmd += ["--broadcast", "--slow"]

    print("EXEC", " ".join(cmd), flush=True)
    print(
        f"ASK={env['ASK_USDC']} FIRE={env['FIRE']} PA_VAULT={env.get('PA_VAULT','')} "
        f"PULL={env.get('PULL_USDC','')}",
        flush=True,
    )
    r = subprocess.run(cmd, cwd=str(ROOT), env=env)
    return r.returncode


if __name__ == "__main__":
    raise SystemExit(main())
