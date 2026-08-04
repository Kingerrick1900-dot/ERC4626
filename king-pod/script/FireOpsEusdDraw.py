#!/usr/bin/env python3
"""Protocol ops eUSD draw — Bound-capped mint to Landing. No USDC desk.

  python3 FireOpsEusdDraw.py --dry
  python3 FireOpsEusdDraw.py --fire                  # deploy+wire only
  python3 FireOpsEusdDraw.py --fire --draw 100000    # draw 100k eUSD
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys

SCRIPT = "script/FireOpsEusdDraw.s.sol:FireOpsEusdDraw"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--fire", action="store_true")
    p.add_argument("--dry", action="store_true")
    p.add_argument("--draw", type=float, default=0, help="eUSD amount (human, 18dp)")
    p.add_argument("--drawer", default=os.environ.get("OPS_DRAWER", ""))
    args = p.parse_args()
    if not args.fire and not args.dry:
        p.error("pass --dry or --fire")

    env = os.environ.copy()
    env["FIRE_OPS_EUSD"] = "1"
    if args.drawer:
        env["OPS_DRAWER"] = args.drawer
    if args.draw > 0:
        env["DRAW_EUSD"] = str(int(args.draw * 10**18))

    rpc = env.get("BASE_RPC_URL") or env.get("RPC_URL") or "https://mainnet.base.org"
    cmd = [
        "forge",
        "script",
        SCRIPT,
        "--rpc-url",
        rpc,
        "-vvv",
    ]
    if args.fire:
        cmd += ["--broadcast", "--slow"]
    else:
        print("DRY: no broadcast", file=sys.stderr)

    print(" ".join(cmd), file=sys.stderr)
    return subprocess.call(cmd, cwd=ROOT, env=env)


if __name__ == "__main__":
    raise SystemExit(main())
