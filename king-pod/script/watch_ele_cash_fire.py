#!/usr/bin/env python3
"""Watch ELE PA doors. When a vault can pull WETH→ELE ≥ ASK, print FIRE + optional forge.

Kingdom raise watcher — does not broadcast unless FIRE_CASH_AUTO=1.
"""
from __future__ import annotations

import os
import subprocess
import sys
import time

from web3 import Web3

RPC = os.environ.get("BASE_RPC_URL") or os.environ.get("RPC_URL") or "https://mainnet.base.org"
PA = Web3.to_checksum_address("0xA090dD1a701408Df1d4d0B85b716c87565f90467")
MORPHO = Web3.to_checksum_address("0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb")
ELE = bytes.fromhex("a4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc")
WETH = bytes.fromhex("8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda")
ASK = int(os.environ.get("ASK_USDC", "700000000000"))

VAULTS = [
    ("GauntletPrime", "0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61"),
    ("SteakPrime", "0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2"),
    ("Steak", "0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183"),
    ("Moonwell", "0xc1256Ae5FF1cf2719D4937adb3bbCCab2E00A2Ca"),
    ("Spark", "0x7BfA7C4f149E7415b73bdeDfe609237e29CBF34A"),
]

PA_ABI = [{
    "name": "flowCaps", "type": "function", "stateMutability": "view",
    "inputs": [{"name": "vault", "type": "address"}, {"name": "id", "type": "bytes32"}],
    "outputs": [{"name": "maxIn", "type": "uint128"}, {"name": "maxOut", "type": "uint128"}],
}]
MM_ABI = [{
    "name": "config", "type": "function", "stateMutability": "view",
    "inputs": [{"name": "id", "type": "bytes32"}],
    "outputs": [{"name": "cap", "type": "uint184"}, {"name": "enabled", "type": "bool"}, {"name": "removableAt", "type": "uint64"}],
}, {
    "name": "isAllocator", "type": "function", "stateMutability": "view",
    "inputs": [{"name": "a", "type": "address"}],
    "outputs": [{"name": "", "type": "bool"}],
}]
MORPHO_ABI = [{
    "name": "position", "type": "function", "stateMutability": "view",
    "inputs": [{"name": "id", "type": "bytes32"}, {"name": "user", "type": "address"}],
    "outputs": [{"name": "supplyShares", "type": "uint256"}, {"name": "borrowShares", "type": "uint128"}, {"name": "collateral", "type": "uint128"}],
}, {
    "name": "market", "type": "function", "stateMutability": "view",
    "inputs": [{"name": "id", "type": "bytes32"}],
    "outputs": [
        {"name": "totalSupplyAssets", "type": "uint128"},
        {"name": "totalSupplyShares", "type": "uint128"},
        {"name": "totalBorrowAssets", "type": "uint128"},
        {"name": "totalBorrowShares", "type": "uint128"},
        {"name": "lastUpdate", "type": "uint128"},
        {"name": "fee", "type": "uint128"},
    ],
}]


def main() -> int:
    interval = int(os.environ.get("POLL_SEC", "30"))
    once = "--once" in sys.argv
    auto = os.environ.get("FIRE_CASH_AUTO", "0") == "1"
    w3 = Web3(Web3.HTTPProvider(RPC, request_kwargs={"timeout": 30}))
    pa = w3.eth.contract(address=PA, abi=PA_ABI)
    morpho = w3.eth.contract(address=MORPHO, abi=MORPHO_ABI)
    print(f"kingdom-cash-watch rpc={RPC} ask={ASK} auto={int(auto)}")
    while True:
        sa, ss, ba, *_ = morpho.functions.market(WETH).call()
        weth_idle = sa - ba if sa > ba else 0
        fired = None
        for name, vault in VAULTS:
            v = Web3.to_checksum_address(vault)
            mm = w3.eth.contract(address=v, abi=MM_ABI)
            max_in, _ = pa.functions.flowCaps(v, ELE).call()
            _, max_out = pa.functions.flowCaps(v, WETH).call()
            _, ele_on, _ = mm.functions.config(ELE).call()
            pa_on = mm.functions.isAllocator(PA).call()
            shares, _, _ = morpho.functions.position(WETH, v).call()
            assets = (sa * shares // ss) if ss else 0
            pull = min(ASK, max_in, max_out, assets, weth_idle) if (ele_on and pa_on and max_in and max_out and assets) else 0
            print(f"{name} eleOn={int(ele_on)} pa={int(pa_on)} maxIn={max_in} maxOut={max_out} wethAssets={assets} pull={pull}")
            if pull >= ASK and fired is None:
                fired = (name, vault, pull)
        if fired:
            name, vault, pull = fired
            print(f"FIRE vault={vault} name={name} pull={pull}")
            if auto:
                env = os.environ.copy()
                env.update({"KING_GO": "1", "FIRE_CASH": "1", "ASK_USDC": str(ASK), "PA_VAULT": vault})
                subprocess.check_call(
                    ["forge", "script", "script/FireCashHunt.s.sol:FireCashHunt",
                     "--rpc-url", RPC, "--broadcast", "--slow", "--private-key", env["PRIVATE_KEY"]],
                    env=env, cwd=os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                )
                return 0
        if once:
            return 0
        time.sleep(interval)


if __name__ == "__main__":
    raise SystemExit(main())
