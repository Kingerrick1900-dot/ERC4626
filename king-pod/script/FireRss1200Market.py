#!/usr/bin/env python3
"""Deploy frozen $1200 RSS/USDC Morpho market. RSS only — no Elepan.

  python3 FireRss1200Market.py --dry
  python3 FireRss1200Market.py --fire
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RPC = os.environ.get("BASE_RPC") or os.environ.get("BASE_RPC_URL") or "https://mainnet.base.org"
SCRIPT = "script/FireRss1200Market.s.sol:FireRss1200Market"


def load_pk() -> None:
    envp = Path("/tmp/cursor/hot_pk.env")
    if envp.is_file():
        for line in envp.read_text().splitlines():
            if "=" in line and not line.strip().startswith("#"):
                k, v = line.strip().split("=", 1)
                os.environ.setdefault(k, v.strip().strip('"').strip("'"))


def main() -> int:
    fire = "--fire" in sys.argv
    load_pk()
    if fire and not os.environ.get("PRIVATE_KEY"):
        print("NEED PRIVATE_KEY", file=sys.stderr)
        return 1
    env = os.environ.copy()
    env["FIRE"] = "1" if fire else "0"
    cmd = ["forge", "script", SCRIPT, "--rpc-url", RPC, "-vv"]
    if fire:
        cmd += ["--broadcast", "--slow"]
    print("EXEC", " ".join(cmd), flush=True)
    return subprocess.run(cmd, cwd=str(ROOT), env=env).returncode


if __name__ == "__main__":
    raise SystemExit(main())
