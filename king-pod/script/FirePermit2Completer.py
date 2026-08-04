#!/usr/bin/env python3
"""Deploy/wire CrownBoundPermit2Completer (Track A PRIMARY).

Usage:
  python3 FirePermit2Completer.py --dry
  python3 FirePermit2Completer.py --fire
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = "script/FirePermit2Completer.s.sol:FirePermit2Completer"
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
    ap.add_argument("--completer", default="")
    args = ap.parse_args()
    if not args.fire and not args.dry:
        args.dry = True
    load_pk()
    env = os.environ.copy()
    env["FIRE"] = "1" if args.fire else "0"
    if args.completer:
        env["P2_COMPLETER"] = args.completer
    if args.fire and not env.get("PRIVATE_KEY"):
        print("NEED PRIVATE_KEY", file=sys.stderr)
        return 1
    cmd = ["forge", "script", SCRIPT, "--rpc-url", RPC, "-vv"]
    if args.fire:
        cmd += ["--broadcast", "--slow"]
    print("EXEC", " ".join(cmd), flush=True)
    return subprocess.run(cmd, cwd=str(ROOT), env=env).returncode


if __name__ == "__main__":
    raise SystemExit(main())
