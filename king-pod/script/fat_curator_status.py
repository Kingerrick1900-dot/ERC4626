#!/usr/bin/env python3
"""Fat curator status — yRSS owner/caps/queue + RSS/BRETT moat markets."""
from __future__ import annotations

import os
from web3 import Web3

RPC = os.environ.get("BASE_RPC_URL") or os.environ.get("ETH_RPC_URL") or "https://base.llamarpc.com"
YRSS = Web3.to_checksum_address("0xF80C0529bD94C773844E459853CD91B9263dD525")
PA = Web3.to_checksum_address("0xA090dD1a701408Df1d4d0B85b716c87565f90467")
MORPHO = Web3.to_checksum_address("0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb")
RSS_M = bytes.fromhex("40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794")
BRETT_M = bytes.fromhex("f6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16")

MM_ABI = [
    {"name": "name", "outputs": [{"type": "string"}], "inputs": [], "stateMutability": "view", "type": "function"},
    {"name": "owner", "outputs": [{"type": "address"}], "inputs": [], "stateMutability": "view", "type": "function"},
    {"name": "curator", "outputs": [{"type": "address"}], "inputs": [], "stateMutability": "view", "type": "function"},
    {"name": "fee", "outputs": [{"type": "uint96"}], "inputs": [], "stateMutability": "view", "type": "function"},
    {"name": "feeRecipient", "outputs": [{"type": "address"}], "inputs": [], "stateMutability": "view", "type": "function"},
    {"name": "totalAssets", "outputs": [{"type": "uint256"}], "inputs": [], "stateMutability": "view", "type": "function"},
    {"name": "isAllocator", "outputs": [{"type": "bool"}], "inputs": [{"type": "address"}], "stateMutability": "view", "type": "function"},
    {
        "name": "config",
        "outputs": [{"type": "uint184"}, {"type": "bool"}, {"type": "uint64"}],
        "inputs": [{"type": "bytes32"}],
        "stateMutability": "view",
        "type": "function",
    },
    {"name": "supplyQueueLength", "outputs": [{"type": "uint256"}], "inputs": [], "stateMutability": "view", "type": "function"},
    {"name": "supplyQueue", "outputs": [{"type": "bytes32"}], "inputs": [{"type": "uint256"}], "stateMutability": "view", "type": "function"},
]
PA_ABI = [
    {
        "name": "flowCaps",
        "outputs": [{"type": "uint128"}, {"type": "uint128"}],
        "inputs": [{"type": "address"}, {"type": "bytes32"}],
        "stateMutability": "view",
        "type": "function",
    }
]
MORPHO_ABI = [
    {
        "name": "market",
        "outputs": [{"type": "uint128"}] * 6,
        "inputs": [{"type": "bytes32"}],
        "stateMutability": "view",
        "type": "function",
    }
]


def main() -> None:
    w3 = Web3(Web3.HTTPProvider(RPC, request_kwargs={"timeout": 30}))
    v = w3.eth.contract(address=YRSS, abi=MM_ABI)
    pa = w3.eth.contract(address=PA, abi=PA_ABI)
    m = w3.eth.contract(address=MORPHO, abi=MORPHO_ABI)
    print("vault", v.functions.name().call())
    print("owner", v.functions.owner().call())
    print("curator", v.functions.curator().call())
    print("fee", v.functions.fee().call())
    print("feeRecipient", v.functions.feeRecipient().call())
    print("totalAssetsUSDC", v.functions.totalAssets().call() / 1e6)
    print("PA_isAllocator", v.functions.isAllocator(PA).call())
    for label, mid in (("RSS", RSS_M), ("BRETT", BRETT_M)):
        cap, en, _ = v.functions.config(mid).call()
        max_in, max_out = pa.functions.flowCaps(YRSS, mid).call()
        supply, _, borrow, *_ = m.functions.market(mid).call()
        print(f"{label}: enabled={en} capUSDC={cap/1e6:.0f} maxIn={max_in/1e6:.0f} maxOut={max_out/1e6:.0f} morphoSupply={supply}")
    n = v.functions.supplyQueueLength().call()
    print("supplyQueue", n)
    for i in range(n):
        print(f"  [{i}] 0x{v.functions.supplyQueue(i).call().hex()}")


if __name__ == "__main__":
    main()
