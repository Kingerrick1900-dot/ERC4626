#!/usr/bin/env python3
from web3 import Web3
from eth_account import Account
import os
import time

w3 = Web3(Web3.HTTPProvider(os.environ["BASE_RPC_URL"]))
acct = Account.from_key(os.environ["PRIVATE_KEY"])
USDC = Web3.to_checksum_address("0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913")
STEAK = Web3.to_checksum_address("0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183")
ONE_USDC = 10**6

usdc = w3.eth.contract(
    address=USDC,
    abi=[
        {
            "inputs": [{"name": "a", "type": "address"}],
            "name": "balanceOf",
            "outputs": [{"type": "uint256"}],
            "stateMutability": "view",
            "type": "function",
        },
        {
            "inputs": [{"name": "s", "type": "address"}, {"name": "a", "type": "uint256"}],
            "name": "approve",
            "outputs": [{"type": "bool"}],
            "stateMutability": "nonpayable",
            "type": "function",
        },
    ],
)
steak = w3.eth.contract(
    address=STEAK,
    abi=[
        {
            "inputs": [{"name": "assets", "type": "uint256"}, {"name": "receiver", "type": "address"}],
            "name": "deposit",
            "outputs": [{"type": "uint256"}],
            "stateMutability": "nonpayable",
            "type": "function",
        },
        {
            "inputs": [{"name": "a", "type": "address"}],
            "name": "balanceOf",
            "outputs": [{"type": "uint256"}],
            "stateMutability": "view",
            "type": "function",
        },
        {
            "inputs": [{"name": "shares", "type": "uint256"}],
            "name": "convertToAssets",
            "outputs": [{"type": "uint256"}],
            "stateMutability": "view",
            "type": "function",
        },
    ],
)

hot = usdc.functions.balanceOf(acct.address).call()
print("hot", hot, "deposit", ONE_USDC, "eth", w3.eth.get_balance(acct.address))
assert hot >= ONE_USDC
print("sim shares", steak.functions.deposit(ONE_USDC, acct.address).call({"from": acct.address}))


def send(label, fn, gas=400000):
    for _ in range(8):
        latest = w3.eth.get_transaction_count(acct.address, "latest")
        if w3.eth.get_transaction_count(acct.address, "pending") > latest:
            time.sleep(3)
            continue
        gp = max(w3.eth.gas_price, w3.to_wei(0.01, "gwei"))
        tx = fn.build_transaction(
            {
                "from": acct.address,
                "nonce": latest,
                "gas": gas,
                "maxFeePerGas": int(gp * 3),
                "maxPriorityFeePerGas": w3.to_wei(0.01, "gwei"),
                "chainId": 8453,
            }
        )
        h = w3.eth.send_raw_transaction(acct.sign_transaction(tx).raw_transaction)
        print(label, h.hex())
        r = w3.eth.wait_for_transaction_receipt(h, timeout=180)
        print("status", r.status, "gas", r.gasUsed)
        if r.status != 1:
            raise RuntimeError(label + " fail")
        time.sleep(2)
        return h.hex()
    raise RuntimeError("retries " + label)


send("approve", usdc.functions.approve(STEAK, ONE_USDC), 100000)
send("deposit", steak.functions.deposit(ONE_USDC, acct.address), 600000)
shares = steak.functions.balanceOf(acct.address).call()
print(
    "done hot",
    usdc.functions.balanceOf(acct.address).call(),
    "shares",
    shares,
    "assets",
    steak.functions.convertToAssets(shares).call(),
)
