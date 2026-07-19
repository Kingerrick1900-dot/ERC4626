#!/usr/bin/env python3
"""Poll Gauntlet/Steakhouse PA flowCaps for RSS market. Print FIRE when maxIn > 0.

Does not auto-broadcast. Step 2 borrow requires named PA_VAULT + withdraw market params.
Policy: see deployments/FLASH-POLICY.md and deployments/CURATOR-DOOR-OPS.md
"""
from __future__ import annotations

import os
import sys
import time

from web3 import Web3

RPC = os.environ.get("BASE_RPC_URL") or os.environ.get("ETH_RPC_URL") or "https://mainnet.base.org"
PA = Web3.to_checksum_address("0xA090dD1a701408Df1d4d0B85b716c87565f90467")
MARKET = bytes.fromhex(
    "40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794"
)
VAULTS = [
    ("Gauntlet USDC Prime", "0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61"),
    ("Steakhouse Prime USDC", "0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2"),
    ("Steakhouse USDC", "0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183"),
    ("Steakhouse HY USDC", "0xBEEFA7B88064FeEF0cEe02AAeBBd95D30df3878F"),
]

PA_ABI = [
    {
        "name": "flowCaps",
        "type": "function",
        "stateMutability": "view",
        "inputs": [
            {"name": "vault", "type": "address"},
            {"name": "id", "type": "bytes32"},
        ],
        "outputs": [
            {"name": "maxIn", "type": "uint128"},
            {"name": "maxOut", "type": "uint128"},
        ],
    }
]

MM_ABI = [
    {
        "name": "config",
        "type": "function",
        "stateMutability": "view",
        "inputs": [{"name": "id", "type": "bytes32"}],
        "outputs": [
            {
                "name": "",
                "type": "tuple",
                "components": [
                    {"name": "cap", "type": "uint184"},
                    {"name": "enabled", "type": "bool"},
                    {"name": "removableAt", "type": "uint64"},
                ],
            }
        ],
    }
]


def main() -> int:
    interval = int(os.environ.get("POLL_SEC", "60"))
    once = "--once" in sys.argv
    w3 = Web3(Web3.HTTPProvider(RPC, request_kwargs={"timeout": 30}))
    pa = w3.eth.contract(address=PA, abi=PA_ABI)
    mid = MARKET
    print(f"rpc={RPC} poll={interval}s market=0x{MARKET.hex()}")
    while True:
        fires = []
        for name, vault in VAULTS:
            v = Web3.to_checksum_address(vault)
            try:
                max_in, max_out = pa.functions.flowCaps(v, mid).call()
            except Exception as e:
                print(f"{name}: flowCaps ERR {e}")
                continue
            enabled = None
            try:
                mm = w3.eth.contract(address=v, abi=MM_ABI)
                cfg = mm.functions.config(mid).call()
                enabled = bool(cfg[1])
                cap = int(cfg[0])
            except Exception:
                cap = None
            line = f"{name}: enabled={enabled} cap={cap} maxIn={max_in} maxOut={max_out}"
            print(line)
            if max_in > 0:
                fires.append((name, vault, max_in))
        if fires:
            print("=== FIRE — maxIn live. Run FirePositionSeed700k with PA_VAULT + PULL_USDC ===")
            for name, vault, max_in in fires:
                print(f"  PA_VAULT={vault}  PULL_USDC<={max_in}  # {name}")
            if once:
                return 0
        if once:
            return 0
        time.sleep(interval)


if __name__ == "__main__":
    raise SystemExit(main())
