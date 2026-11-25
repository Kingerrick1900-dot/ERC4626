#!/usr/bin/env python3
"""KAR Reallocator watcher — Steakhouse/Gauntlet PublicAllocator playbook.

Watches Base Morpho USDC markets 24/7. When ySYNTH util > 95% and a source
market has idle above threshold with acceptable risk, auto-calls reallocate
(via CrownKarReallocator or PA directly).

Killswitch: banned / depeg markets are skipped and logged.
Foreign vault maxIn (Gauntlet/Steakhouse) is also watched for door-open fires.

Env:
  BASE_RPC_URL, PRIVATE_KEY|HOT_KEY
  REALLOCATOR (optional live CrownKarReallocator)
  FIRE=1 to broadcast (default dry / log only)
  POLL_SEC (default 60)
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent
POLICY_PATH = ROOT / "policy.json"

PA = "0xA090dD1a701408Df1d4d0B85b716c87565f90467"
MORPHO = "0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb"
YSYNTH = "0xc91f3Bc556001eF7ACFCB869eC0fC29ac780c35C"
YRSS = "0xF80C0529bD94C773844E459853CD91B9263dD525"
HOT = "0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1"
USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
EUSD = "0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a"
IRM = "0x46415998764C29aB2a25CbeA6254146D50D22687"
ORACLE_EUSD = "0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e"
LLTV_86 = str(860000000000000000)

SYNTH_ID = "0x08039ffa5b39da99b2847c66f738ecf8f149a00b4374818b7cdf4d134dd33fcd"
IDLE_ID = "0x38c846197ac32a752a60c25d4536ebb0c3920c532e9a859c38c91efb7b8c2abb"
CBBTC_ID = "0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836"
WETH_ID = "0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda"
RSS_ID = "0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794"

# risk score 0..10000 — kill if above MAX_RISK
RISK = {
    IDLE_ID: 1000,
    CBBTC_ID: 2000,
    WETH_ID: 2500,
    SYNTH_ID: 5000,
    RSS_ID: 4500,
}
MAX_RISK = 7000
UTIL_TRIGGER_BPS = 9500
IDLE_THRESHOLD = 1_000 * 10**6  # $1k

FOREIGN = [
    ("Gauntlet USDC Prime", "0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61"),
    ("Steakhouse Prime USDC", "0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2"),
    ("Steakhouse USDC", "0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183"),
    ("Steakhouse HY USDC", "0xBEEFA7B88064FeEF0cEe02AAeBBd95D30df3878F"),
]

BANNED: set[str] = set()


def cast(*args: str, rpc: str) -> str:
    return subprocess.check_output(["cast", *args, "--rpc-url", rpc], text=True).strip()


def market_state(rpc: str, mid: str) -> tuple[int, int, int, int]:
    out = cast(
        "call",
        MORPHO,
        "market(bytes32)(uint128,uint128,uint128,uint128,uint128,uint128)",
        mid,
        rpc=rpc,
    )
    lines = [ln.split()[0] for ln in out.splitlines() if ln.strip()]
    supply = int(lines[0])
    borrow = int(lines[2])
    idle = supply - borrow if supply > borrow else 0
    util = (borrow * 10_000 // supply) if supply else 0
    return supply, borrow, idle, util


def vault_shares(rpc: str, mid: str, vault: str) -> int:
    out = cast(
        "call",
        MORPHO,
        "position(bytes32,address)(uint256,uint128,uint128)",
        mid,
        vault,
        rpc=rpc,
    )
    return int(out.splitlines()[0].split()[0])


def flow_caps(rpc: str, vault: str, mid: str) -> tuple[int, int]:
    out = cast(
        "call",
        PA,
        "flowCaps(address,bytes32)(uint128,uint128)",
        vault,
        mid,
        rpc=rpc,
    )
    lines = [ln.split()[0] for ln in out.splitlines() if ln.strip()]
    return int(lines[0]), int(lines[1])


def is_allocator(rpc: str, vault: str, who: str) -> bool:
    out = cast("call", vault, "isAllocator(address)(bool)", who, rpc=rpc)
    return out.lower().startswith("true")


def killswitch_on(rpc: str, reallocator: str) -> bool:
    if not reallocator:
        return False
    try:
        out = cast("call", reallocator, "killswitch()(bool)", rpc=rpc)
        return out.lower().startswith("true")
    except subprocess.CalledProcessError:
        return False


def ban_check(mid: str, risk: int) -> str | None:
    if mid.lower() in {b.lower() for b in BANNED}:
        return "banned"
    if risk > MAX_RISK:
        return "risk"
    return None


def log(msg: str) -> None:
    print(msg, flush=True)


def try_fire_pa(
    rpc: str,
    pk: str,
    from_id: str,
    amount: int,
) -> bool:
    """Broadcast PA.reallocateTo ySYNTH: withdraw from_id → supply SYNTH."""
    params = cast(
        "call",
        MORPHO,
        "idToMarketParams(bytes32)(address,address,address,address,uint256)",
        from_id,
        rpc=rpc,
    )
    pl = [ln.split()[0] for ln in params.splitlines() if ln.strip()]
    loan, coll, oracle, irm, lltv = pl[0], pl[1], pl[2], pl[3], pl[4]

    # Build calldata via cast
    # reallocateTo(address,(MarketParams,uint128)[],MarketParams)
    withdraw_tuple = f"(({loan},{coll},{oracle},{irm},{lltv}),{amount})"
    supply_tuple = f"({USDC},{EUSD},{ORACLE_EUSD},{IRM},{LLTV_86})"
    try:
        subprocess.check_call(
            [
                "cast",
                "send",
                PA,
                "reallocateTo(address,(address,address,address,address,uint256,uint128)[],(address,address,address,address,uint256))",
                YSYNTH,
                f"[{withdraw_tuple}]",
                supply_tuple,
                "--private-key",
                pk,
                "--rpc-url",
                rpc,
                "--legacy",
            ]
        )
        return True
    except subprocess.CalledProcessError as e:
        log(f"FIRE_REVERT from={from_id} amt={amount} err={e}")
        return False


def scan_once(rpc: str, pk: str, fire: bool, reallocator: str) -> dict:
    report: dict = {"fires": [], "skips": [], "foreign": []}

    if killswitch_on(rpc, reallocator):
        log("KILLSWITCH armed — refuse all reallocates")
        report["skips"].append({"reason": "killswitch"})
        return report

    try:
        _s, _b, idle, util = market_state(rpc, SYNTH_ID)
    except Exception as e:
        log(f"synth_market_err {e}")
        return report

    pa_ok = is_allocator(rpc, YSYNTH, PA)
    hot_usdc = int(cast("call", USDC, "balanceOf(address)(uint256)", HOT, rpc=rpc).split()[0])
    log(
        f"ySYNTH utilBps={util} idle={idle} paAllocator={pa_ok} hotUsdc={hot_usdc}"
    )

    # Foreign door watch (Steakhouse/Gauntlet → our markets)
    for name, vault in FOREIGN:
        try:
            max_in_s, _ = flow_caps(rpc, vault, SYNTH_ID)
            max_in_r, _ = flow_caps(rpc, vault, RSS_ID)
        except Exception as e:
            log(f"foreign_err {name} {e}")
            continue
        row = {"name": name, "vault": vault, "synthMaxIn": max_in_s, "rssMaxIn": max_in_r}
        report["foreign"].append(row)
        if max_in_s > 0 or max_in_r > 0:
            log(f"FOREIGN_DOOR {name} synthMaxIn={max_in_s} rssMaxIn={max_in_r}")

    if util < UTIL_TRIGGER_BPS:
        log(f"skip util {util} < {UTIL_TRIGGER_BPS}")
        report["skips"].append({"reason": "util", "util": util})
        return report

    sources = [
        ("IDLE", IDLE_ID),
        ("cbBTC", CBBTC_ID),
        ("WETH", WETH_ID),
    ]
    for label, mid in sources:
        risk = RISK.get(mid, 9999)
        reason = ban_check(mid, risk)
        if reason:
            log(f"SKIP {label} {reason} risk={risk}")
            report["skips"].append({"market": label, "reason": reason})
            continue
        try:
            shares = vault_shares(rpc, mid, YSYNTH)
            _s, _b, src_idle, src_util = market_state(rpc, mid)
            max_in, max_out = flow_caps(rpc, YSYNTH, mid)
            max_in_t, _ = flow_caps(rpc, YSYNTH, SYNTH_ID)
        except Exception as e:
            log(f"source_err {label} {e}")
            continue

        log(
            f"SRC {label} shares={shares} idle={src_idle} util={src_util} "
            f"maxOut={max_out} targetMaxIn={max_in_t} risk={risk}"
        )
        if shares == 0:
            report["skips"].append({"market": label, "reason": "no_position"})
            continue
        if src_idle < IDLE_THRESHOLD:
            report["skips"].append({"market": label, "reason": "idle_below_threshold", "idle": src_idle})
            continue
        amt = min(src_idle, max_out, max_in_t)
        if amt <= 0:
            report["skips"].append({"market": label, "reason": "flow_cap"})
            continue

        log(f"TRIGGER pull {amt} from {label} → SYNTH")
        if fire and pk:
            ok = try_fire_pa(rpc, pk, mid, amt)
            report["fires"].append({"market": label, "amount": amt, "ok": ok})
        else:
            report["fires"].append({"market": label, "amount": amt, "ok": None, "dry": True})
            log("DRY — set FIRE=1 to broadcast")

    return report


def main() -> int:
    once = "--once" in sys.argv
    fire = os.environ.get("FIRE", "0") == "1" or "--fire" in sys.argv
    rpc = os.environ.get("BASE_RPC_URL") or "https://mainnet.base.org"
    pk = os.environ.get("PRIVATE_KEY") or os.environ.get("HOT_KEY") or ""
    reallocator = os.environ.get("REALLOCATOR", "")
    if not reallocator and POLICY_PATH.exists():
        pol = json.loads(POLICY_PATH.read_text())
        reallocator = pol.get("rails", {}).get("CrownKarReallocator", "") or ""
    if reallocator in ("", "PENDING", "pending"):
        reallocator = ""
    interval = int(os.environ.get("POLL_SEC", "60"))

    log(f"KAR-realloc rpc={rpc} fire={fire} poll={interval}s realloc={reallocator or 'unset'}")
    while True:
        try:
            report = scan_once(rpc, pk, fire, reallocator)
            log("REPORT " + json.dumps(report))
        except Exception as e:
            log(f"scan_err {e}")
        if once:
            return 0
        time.sleep(interval)


if __name__ == "__main__":
    raise SystemExit(main())
