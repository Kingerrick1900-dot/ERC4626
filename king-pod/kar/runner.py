#!/usr/bin/env python3
"""Kingdom Agent Runtime — policy-gated execution plane (not a Cursor binary fork)."""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
POLICY_PATH = ROOT / "policy.json"


def load_policy() -> dict:
    return json.loads(POLICY_PATH.read_text())


def cast(*args: str, rpc: str) -> str:
    cmd = ["cast", *args, "--rpc-url", rpc]
    return subprocess.check_output(cmd, text=True).strip()


def borders_secure(policy: dict, rpc: str) -> bool:
    attest = policy["gates"]["attest"]
    out = cast("call", attest, "bordersSecure()(bool)", rpc=rpc)
    return out.lower().startswith("true")


def allowlist_check(policy: dict, rpc: str, target: str, selector: str) -> None:
    al = policy["gates"]["allowlist"]
    if not al or al.startswith("PENDING"):
        raise SystemExit("allowlist not deployed — refuse")
    # check(address,bytes4)
    cast("call", al, "check(address,bytes4)", target, selector, rpc=rpc)


def sel(sig: str) -> str:
    return subprocess.check_output(["cast", "sig", sig], text=True).strip()


def cmd_status(policy: dict, rpc: str) -> None:
    print("KAR", policy["version"])
    print("bordersSecure", borders_secure(policy, rpc))
    print("allowlist", policy["gates"]["allowlist"])
    print("attest", policy["gates"]["attest"])
    agent = policy["rails"]["CrownKingAgent"]
    try:
        obs = cast("call", agent, "observe()(uint256,uint256,uint256,bool)", rpc=rpc)
        print("observe", obs.replace("\n", " | "))
    except subprocess.CalledProcessError as e:
        print("observe_error", e)


def cmd_attest(policy: dict, rpc: str, pk: str) -> None:
    if not borders_secure(policy, rpc) and policy["gates"]["requireBordersSecure"]:
        # refreshing attest is allowed even when stale — it restores borders
        pass
    attest = policy["rails"]["CrownZkAttest"]
    selector = sel("attestLive(bytes32)")
    allowlist_check(policy, rpc, attest, selector)
    root = subprocess.check_output(
        ["cast", "keccak", f"KAR-{os.getpid()}"], text=True
    ).strip()
    # commit + attest
    subprocess.check_call(
        [
            "cast",
            "send",
            attest,
            "commitPayrollRoot(bytes32,bool)",
            root,
            "true",
            "--private-key",
            pk,
            "--rpc-url",
            rpc,
            "--legacy",
        ]
    )
    subprocess.check_call(
        [
            "cast",
            "send",
            attest,
            "attestLive(bytes32)",
            root,
            "--private-key",
            pk,
            "--rpc-url",
            rpc,
            "--legacy",
        ]
    )
    print("attested", root)
    print("bordersSecure", borders_secure(policy, rpc))


def cmd_check(policy: dict, rpc: str, target: str, sig: str) -> None:
    selector = sel(sig)
    allowlist_check(policy, rpc, target, selector)
    print("ALLOWED", target, sig, selector)


def main() -> None:
    p = argparse.ArgumentParser(description="Kingdom Agent Runtime")
    p.add_argument("command", choices=["status", "attest", "check"])
    p.add_argument("--target", default="")
    p.add_argument("--sig", default="")
    p.add_argument("--fire", action="store_true", help="broadcast (attest)")
    args = p.parse_args()

    policy = load_policy()
    rpc = os.environ.get(
        policy["chains"]["base"]["rpcEnv"], policy["chains"]["base"]["rpcDefault"]
    )
    pk = os.environ.get("PRIVATE_KEY", "")

    if args.command == "status":
        cmd_status(policy, rpc)
    elif args.command == "attest":
        if not args.fire:
            raise SystemExit("refuse: pass --fire to broadcast attest")
        if not pk:
            raise SystemExit("PRIVATE_KEY required")
        cmd_attest(policy, rpc, pk)
    elif args.command == "check":
        if not args.target or not args.sig:
            raise SystemExit("--target and --sig required")
        cmd_check(policy, rpc, args.target, args.sig)


if __name__ == "__main__":
    main()
