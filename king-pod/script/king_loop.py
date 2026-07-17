#!/usr/bin/env python3
"""King-line loop — proven rails, small txs, capped gas limits.

1) Hot USDC → yRSS deposit
2) PA reallocateTo (yRSS cbBTC → RSS)
3) Morpho borrow idle → LOOP
4) LOOP USDC → Hot
Repeat.

Gas discipline (King):
- Split: one step = one tx (never mega-batch).
- Dry-run: callStatic + estimateGas before send.
- Cap: gasLimit is a budget, not a requirement — shrink to estimate+buffer
  and to what the wallet can preflight (balance >= gasLimit * maxFee).
- Base Azul ~16.7M hard cap; our per-step hard cap stays far below.
- Optional OFFPEAK_ONLY waits for quiet UTC windows.
- Elixir/Circle USDC paymaster is a future AA rail (not EOA here).

Env: PRIVATE_KEY, LOOP_PRIVATE_KEY, MAX_LOOPS, MIN_USDC, BASE_RPC_URL,
     LOOP_SEND_RPC, GAS_BUFFER, HARD_GAS_CAP, OFFPEAK_ONLY,
     AUTO_RESTART, RESTART_SLEEP
"""

from __future__ import annotations

import os
import time
from datetime import datetime, timezone
from eth_account import Account
from web3 import Web3

def pick_rpc() -> str:
    # Prefer private/send RPC; demote public mainnet.base.org (429 + stale reads).
    base = (os.environ.get("BASE_RPC_URL") or "").strip()
    publicish = {"https://mainnet.base.org", "https://base.publicnode.com"}
    candidates = [
        os.environ.get("LOOP_SEND_RPC"),
        base if base and base.rstrip("/") not in publicish else None,
        "https://base.llamarpc.com",
        "https://rpc.ankr.com/base",
        "https://1rpc.io/base",
        base if base else None,
        "https://mainnet.base.org",
    ]
    seen: set[str] = set()
    for url in candidates:
        if not url or url in seen:
            continue
        seen.add(url)
        try:
            w = Web3(Web3.HTTPProvider(url, request_kwargs={"timeout": 25}))
            _ = w.eth.block_number
            return url
        except Exception:
            continue
    return "https://mainnet.base.org"


RPC = pick_rpc()

HOT = Web3.to_checksum_address("0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1")
LOOP = Web3.to_checksum_address("0x8d3cfbFc6A276f118579517E4d166e94C66F8585")
YRSS = Web3.to_checksum_address("0xF80C0529bD94C773844E459853CD91B9263dD525")
PA = Web3.to_checksum_address("0xA090dD1a701408Df1d4d0B85b716c87565f90467")
MORPHO = Web3.to_checksum_address("0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb")
USDC = Web3.to_checksum_address("0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913")
RSS = Web3.to_checksum_address("0x7a305D07B537359cf468eAea9bb176E5308bC337")
ORACLE = Web3.to_checksum_address("0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e")
IRM = Web3.to_checksum_address("0x46415998764C29aB2a25CbeA6254146D50D22687")
CBBTC = Web3.to_checksum_address("0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf")
CBBTC_ORACLE = Web3.to_checksum_address("0x663BECd10daE6C4A3Dcd89F1d76c1174199639B9")
MARKET_RSS = bytes.fromhex("40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794")
MARKET_BTC = bytes.fromhex("9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836")
LLTV_RSS = 770000000000000000
LLTV_BTC = 860000000000000000

MAX_LOOPS = int(os.environ.get("MAX_LOOPS", "20"))
MIN_USDC = int(os.environ.get("MIN_USDC", "100000"))
# ~0.00005 ETH covers many 200k-gas steps at Base fee levels
GAS_FLOOR = int(os.environ.get("GAS_FLOOR_WEI", str(int(0.00005 * 1e18))))
LOOP_GAS_MIN = int(os.environ.get("LOOP_GAS_MIN_WEI", str(int(0.00005 * 1e18))))
GAS_BUFFER = int(os.environ.get("GAS_BUFFER", "20000"))  # small headroom over estimate
# Per-step hard cap — budget, not ambition. Lower than wallet can afford.
HARD_GAS_CAP = int(os.environ.get("HARD_GAS_CAP", "350000"))
OFFPEAK_ONLY = os.environ.get("OFFPEAK_ONLY", "").strip() in ("1", "true", "yes")
AUTO_RESTART = os.environ.get("AUTO_RESTART", "").strip().lower() in ("1", "true", "yes")
RESTART_SLEEP = int(os.environ.get("RESTART_SLEEP", "45"))


def load_pk(name: str, fallback: str | None = None) -> str:
    pk = os.environ.get(name, "").strip()
    if not pk and fallback and os.path.exists(fallback):
        pk = open(fallback).read().strip()
    if not pk:
        raise SystemExit(f"missing {name}")
    return pk if pk.startswith("0x") else "0x" + pk


def main() -> None:
    hot = Account.from_key(load_pk("PRIVATE_KEY"))
    loop = Account.from_key(load_pk("LOOP_PRIVATE_KEY", "/tmp/loop_pk.txt"))
    assert hot.address.lower() == HOT.lower()
    assert loop.address.lower() == LOOP.lower()

    w3 = Web3(Web3.HTTPProvider(RPC))

    usdc = w3.eth.contract(
        address=USDC,
        abi=[
            {"inputs": [{"name": "a", "type": "address"}], "name": "balanceOf", "outputs": [{"type": "uint256"}], "stateMutability": "view", "type": "function"},
            {"inputs": [{"name": "s", "type": "address"}, {"name": "a", "type": "uint256"}], "name": "approve", "outputs": [{"type": "bool"}], "stateMutability": "nonpayable", "type": "function"},
            {"inputs": [{"name": "t", "type": "address"}, {"name": "a", "type": "uint256"}], "name": "transfer", "outputs": [{"type": "bool"}], "stateMutability": "nonpayable", "type": "function"},
        ],
    )
    yrss = w3.eth.contract(
        address=YRSS,
        abi=[
            {"inputs": [{"name": "assets", "type": "uint256"}, {"name": "receiver", "type": "address"}], "name": "deposit", "outputs": [{"type": "uint256"}], "stateMutability": "nonpayable", "type": "function"},
            {"inputs": [], "name": "totalAssets", "outputs": [{"type": "uint256"}], "stateMutability": "view", "type": "function"},
        ],
    )
    pa = w3.eth.contract(
        address=PA,
        abi=[
            {
                "inputs": [
                    {"name": "vault", "type": "address"},
                    {
                        "components": [
                            {
                                "components": [
                                    {"name": "loanToken", "type": "address"},
                                    {"name": "collateralToken", "type": "address"},
                                    {"name": "oracle", "type": "address"},
                                    {"name": "irm", "type": "address"},
                                    {"name": "lltv", "type": "uint256"},
                                ],
                                "name": "marketParams",
                                "type": "tuple",
                            },
                            {"name": "amount", "type": "uint128"},
                        ],
                        "name": "withdrawals",
                        "type": "tuple[]",
                    },
                    {
                        "components": [
                            {"name": "loanToken", "type": "address"},
                            {"name": "collateralToken", "type": "address"},
                            {"name": "oracle", "type": "address"},
                            {"name": "irm", "type": "address"},
                            {"name": "lltv", "type": "uint256"},
                        ],
                        "name": "supplyMarketParams",
                        "type": "tuple",
                    },
                ],
                "name": "reallocateTo",
                "outputs": [],
                "stateMutability": "payable",
                "type": "function",
            }
        ],
    )
    morpho = w3.eth.contract(
        address=MORPHO,
        abi=[
            {
                "inputs": [{"name": "id", "type": "bytes32"}],
                "name": "market",
                "outputs": [{"type": "uint128"}, {"type": "uint128"}, {"type": "uint128"}, {"type": "uint128"}, {"type": "uint128"}, {"type": "uint128"}],
                "stateMutability": "view",
                "type": "function",
            },
            {
                "inputs": [{"name": "id", "type": "bytes32"}, {"name": "user", "type": "address"}],
                "name": "position",
                "outputs": [{"type": "uint256"}, {"type": "uint128"}, {"type": "uint128"}],
                "stateMutability": "view",
                "type": "function",
            },
            {
                "inputs": [
                    {
                        "components": [
                            {"name": "loanToken", "type": "address"},
                            {"name": "collateralToken", "type": "address"},
                            {"name": "oracle", "type": "address"},
                            {"name": "irm", "type": "address"},
                            {"name": "lltv", "type": "uint256"},
                        ],
                        "name": "marketParams",
                        "type": "tuple",
                    },
                    {"name": "assets", "type": "uint256"},
                    {"name": "shares", "type": "uint256"},
                    {"name": "onBehalf", "type": "address"},
                    {"name": "receiver", "type": "address"},
                ],
                "name": "borrow",
                "outputs": [{"type": "uint256"}, {"type": "uint256"}],
                "stateMutability": "nonpayable",
                "type": "function",
            },
        ],
    )

    cb_params = (USDC, CBBTC, CBBTC_ORACLE, IRM, LLTV_BTC)
    rss_params = (USDC, RSS, ORACLE, IRM, LLTV_RSS)

    def bal(addr, retries: int = 8):
        last = 0
        for i in range(retries):
            try:
                last = int(usdc.functions.balanceOf(addr).call())
                return last
            except Exception:
                time.sleep(0.8 + 0.3 * i)
        return last

    def wait_bal(addr, min_amt: int, rounds: int = 10):
        """Wait for USDC to show after a transfer (RPC lag / indexing)."""
        got = 0
        for i in range(rounds):
            got = bal(addr)
            if got >= min_amt:
                return got
            time.sleep(1.0 + 0.3 * i)
        return got

    def eth_bal(addr):
        for _ in range(5):
            try:
                return w3.eth.get_balance(addr)
            except Exception:
                time.sleep(1)
        return w3.eth.get_balance(addr)

    def read_nonce(addr):
        vals = []
        for _ in range(3):
            try:
                vals.append(w3.eth.get_transaction_count(addr, "latest"))
            except Exception:
                time.sleep(0.5)
        return max(vals) if vals else w3.eth.get_transaction_count(addr, "latest")

    def fit_gas_budget(have: int, value: int, est: int, max_fee: int) -> tuple[int, int]:
        """gasLimit is a budget. Cap to estimate, hard cap, and wallet preflight.

        Node rejects if balance < gasLimit * maxFee + value — even when actual
        usage would fit. Lower the limit; worst case OOG revert and retry smaller.
        """
        gas_limit = min(int(est) + GAS_BUFFER, HARD_GAS_CAP)
        # keep a dust reserve so we don't zero the wallet on fees
        reserve = 5_000_000_000_000  # 0.000005 ETH
        spendable = max(0, have - value - reserve)
        if max_fee <= 0:
            max_fee = 1_000_000
        affordable = spendable // max_fee if max_fee else 0
        if affordable < 21_000:
            # shrink fee first so a simple step can still clear
            max_fee = max(1_000_000, spendable // max(gas_limit, 21_000))
            affordable = spendable // max_fee if max_fee else 0
        if affordable > 0:
            gas_limit = min(gas_limit, affordable)
        # never below estimate (would be guaranteed OOG) unless wallet forces it
        if gas_limit < est and affordable >= est:
            gas_limit = int(est)
        return gas_limit, max_fee

    def send(acct, fn, label, value=0, fallback_gas=200000):
        """callStatic → estimateGas → cap limit to wallet → send. One small step."""
        for attempt in range(8):
            try:
                # 1) dry-run (callStatic) — soft-fail: allowance/index lag can false-negative
                try:
                    fn.call({"from": acct.address, "value": value})
                except Exception as e:
                    print(f"  {label} callStatic warn: {type(e).__name__}: {str(e)[:120]}")

                # 2) estimate
                try:
                    est = int(fn.estimate_gas({"from": acct.address, "value": value}))
                except Exception as e:
                    print(f"  {label} estimate fail ({e}); fallback {fallback_gas}")
                    est = fallback_gas
                # first PA/borrow attempts often under-estimate; pad those labels
                if label in ("pa_reallocate", "borrow_to_loop", "deposit_yrss"):
                    est = max(est, int(fallback_gas * 0.9))

                gp = max(w3.eth.gas_price, 1_000_000)  # >= 0.001 gwei
                max_fee = max(gp * 2, 2_000_000)
                prio = min(1_000_000, max_fee)

                nonce = read_nonce(acct.address)
                try:
                    pending = w3.eth.get_transaction_count(acct.address, "pending")
                except Exception:
                    pending = nonce
                if pending > nonce and pending - nonce < 5:
                    print(f"  {label} pending gap {pending-nonce}; replace bump nonce={nonce}")
                    max_fee = max(gp * 10, 20_000_000)
                    prio = min(max(2_000_000, max_fee // 5), max_fee)
                else:
                    max_fee = int(max_fee * (1 + 0.15 * attempt))
                    prio = min(int(prio * (1 + 0.5 * attempt)), max_fee)

                have = eth_bal(acct.address)
                gas_limit, max_fee = fit_gas_budget(have, value, est, max_fee)
                prio = min(prio, max_fee)
                need = gas_limit * max_fee + value
                print(
                    f"  {label} est={est} limit={gas_limit} maxFee={max_fee} "
                    f"need={need} have={have} nonce={nonce}"
                )
                if have < need:
                    raise RuntimeError(
                        f"preflight short: have={have} need={need} "
                        f"(lower HARD_GAS_CAP or fund tiny ETH)"
                    )

                tx = fn.build_transaction(
                    {
                        "from": acct.address,
                        "nonce": nonce,
                        "gas": gas_limit,
                        "value": value,
                        "maxFeePerGas": max_fee,
                        "maxPriorityFeePerGas": prio,
                        "chainId": 8453,
                    }
                )
                h = w3.eth.send_raw_transaction(acct.sign_transaction(tx).raw_transaction)
                print(f"  {label} {h.hex()}")
                r = w3.eth.wait_for_transaction_receipt(h, timeout=180)
                print(f"  status={r.status} used={r.gasUsed} (budget={gas_limit})")
                if r.status != 1:
                    raise RuntimeError(f"{label} reverted")
                time.sleep(1.2)
                return h.hex()
            except Exception as e:
                print(f"  {label} attempt {attempt}: {type(e).__name__}: {str(e)[:200]}")
                time.sleep(2 + attempt)
        raise RuntimeError(f"{label} exhausted")

    def cbbtc_assets():
        for _ in range(8):
            try:
                pos = morpho.functions.position(MARKET_BTC, YRSS).call()
                mk = morpho.functions.market(MARKET_BTC).call()
                return 0 if mk[1] == 0 else pos[0] * mk[0] // mk[1]
            except Exception as e:
                print(f"  cbbtc_assets retry: {type(e).__name__}")
                time.sleep(1.5)
        raise RuntimeError("cbbtc_assets failed")

    def idle(min_expected: int = 0, rounds: int = 12):
        """Read market idle with retries. Public RPCs sometimes return stale 0."""
        last = 0
        for i in range(rounds):
            try:
                mk = morpho.functions.market(MARKET_RSS).call()
                last = max(0, int(mk[0]) - int(mk[2]))
                if last >= min_expected or (min_expected == 0 and i >= 2):
                    return last
                print(f"  idle={last} < expected {min_expected}; retry {i}")
            except Exception as e:
                print(f"  idle retry: {type(e).__name__}")
            time.sleep(1.2 + 0.4 * i)
        return last

    if OFFPEAK_ONLY:
        # Quiet windows: Sat/Sun UTC or 04:00–12:00 UTC weekdays
        while True:
            now = datetime.now(timezone.utc)
            quiet = now.weekday() >= 5 or 4 <= now.hour < 12
            if quiet:
                print(f"off-peak OK utc={now.isoformat()}")
                break
            print(f"off-peak wait utc={now.isoformat()} (sleep 600s)")
            time.sleep(600)

    # gas top-up to loop if needed (small — exact rail, not theater)
    loop_eth_now = eth_bal(LOOP)
    if loop_eth_now < LOOP_GAS_MIN:
        top = LOOP_GAS_MIN - loop_eth_now
        print(f"top-up loop gas {top}")
        nonce = read_nonce(hot.address)
        gp = max(w3.eth.gas_price, 1_000_000)
        max_fee = max(gp * 2, 2_000_000)
        gas_limit, max_fee = fit_gas_budget(eth_bal(HOT), top, 21000, max_fee)
        gas_limit = max(21000, min(gas_limit, 21000))
        prio = min(1_000_000, max_fee)
        tx = {
            "to": LOOP,
            "value": top,
            "nonce": nonce,
            "gas": gas_limit,
            "maxFeePerGas": max_fee,
            "maxPriorityFeePerGas": prio,
            "chainId": 8453,
            "type": 2,
        }
        h = w3.eth.send_raw_transaction(hot.sign_transaction(tx).raw_transaction)
        print("  gas", h.hex())
        w3.eth.wait_for_transaction_receipt(h, timeout=180)
        time.sleep(1)

    # If USDC already on loop (partial prior run), recycle first
    loop_usdc = bal(LOOP)
    if loop_usdc >= MIN_USDC:
        print(f"recycle loop→hot first ({loop_usdc})")
        send(loop, usdc.functions.transfer(HOT, loop_usdc), "loop_to_hot", fallback_gas=65000)

    print("KING LOOP START (capped gasLimit, split steps, callStatic)")
    print(f"hard_gas_cap={HARD_GAS_CAP} buffer={GAS_BUFFER} rpc={RPC}")
    print(f"hot USDC={bal(HOT)} eth={eth_bal(HOT)}")
    print(f"loop USDC={bal(LOOP)} eth={eth_bal(LOOP)}")

    for i in range(1, MAX_LOOPS + 1):
        hot_usdc = wait_bal(HOT, MIN_USDC, rounds=6) if i > 1 else bal(HOT)
        hot_eth = eth_bal(HOT)
        print(f"\n=== LOOP {i}/{MAX_LOOPS} hotUSDC={hot_usdc} eth={hot_eth} ===")
        if hot_usdc < MIN_USDC:
            # one more settle pass — recycle lag after prior lap
            hot_usdc = wait_bal(HOT, MIN_USDC, rounds=8)
            if hot_usdc < MIN_USDC:
                print("stop: hot USDC below MIN")
                break
        if hot_eth < GAS_FLOOR:
            time.sleep(1.5)
            hot_eth = eth_bal(HOT)
            if hot_eth < GAS_FLOOR:
                print("stop: hot eth gas floor")
                break

        amount = hot_usdc

        send(hot, usdc.functions.approve(YRSS, amount), "approve_yrss", fallback_gas=60000)
        send(hot, yrss.functions.deposit(amount, HOT), "deposit_yrss", fallback_gas=280000)

        assets = cbbtc_assets()
        pull = assets if assets <= 1 else assets - 1
        print(f"  cbBTC assets={assets} pull={pull}")
        if pull < MIN_USDC:
            print("stop: nothing to PA")
            break
        send(
            hot,
            pa.functions.reallocateTo(YRSS, [(cb_params, pull)], rss_params),
            "pa_reallocate",
            fallback_gas=250000,
        )

        # After PA, idle should be ≈ pull. Don't trust a single flaky 0.
        idle_amt = idle(min_expected=min(pull, MIN_USDC), rounds=14)
        print(f"  idle={idle_amt}")
        if idle_amt < MIN_USDC:
            print("stop: no idle after retries")
            break
        # Borrow only what is idle (never more than pull this lap)
        borrow_amt = min(idle_amt, pull)
        send(
            hot,
            morpho.functions.borrow(rss_params, borrow_amt, 0, HOT, LOOP),
            "borrow_to_loop",
            fallback_gas=150000,
        )

        got = wait_bal(LOOP, MIN_USDC, rounds=10)
        print(f"  loop received {got}")
        if got < MIN_USDC:
            print("stop: loop dust")
            break
        send(loop, usdc.functions.transfer(HOT, got), "loop_to_hot", fallback_gas=65000)
        # Recycle must be visible before next lap — else false "hot USDC below MIN"
        back = wait_bal(HOT, MIN_USDC, rounds=12)
        print(f"  recycled to hot={back}")

        mk = morpho.functions.market(MARKET_RSS).call()
        print(f"  PoD supply={mk[0]} borrow={mk[2]} util={mk[2]/mk[0]*100 if mk[0] else 0:.4f}%")
        print(f"  yRSS TA={yrss.functions.totalAssets().call()} hot={bal(HOT)} eth={eth_bal(HOT)}")

    print("\nKING LOOP DONE")
    try:
        print(f"hot USDC={bal(HOT)} eth={eth_bal(HOT)} loop USDC={bal(LOOP)} eth={eth_bal(LOOP)}")
        mk = morpho.functions.market(MARKET_RSS).call()
        print(f"PoD supply={mk[0]} borrow={mk[2]}")
        print(f"yRSS TA={yrss.functions.totalAssets().call()}")
    except Exception as e:
        print(f"final read flake: {e}")


if __name__ == "__main__":
    # AUTO_RESTART=1 → engine keeps cycling until gas/USDC floor; no hand on the tiller.
    while True:
        try:
            main()
        except Exception as e:
            print(f"ENGINE fault: {type(e).__name__}: {e}")
        if not AUTO_RESTART:
            break
        print(f"AUTO_RESTART: sleep {RESTART_SLEEP}s then fire again")
        time.sleep(RESTART_SLEEP)
