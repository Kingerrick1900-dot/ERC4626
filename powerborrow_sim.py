#!/usr/bin/env python3
"""Morpho powerBorrow + Public Allocator simulation — numbers only."""
from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

RPC = os.environ.get("BASE_RPC") or os.environ.get("BASE_RPC_URL") or "https://mainnet.base.org"
MARKET = "0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794"
MORPHO = "0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb"
KING = "0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1"
RSS = "0x7a305D07B537359cf468eAea9bb176E5308bC337"
ORACLE = "0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e"
ETH_FEED = "0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70"
LLTV = 0.77
GAS_UNITS = 650_000
SEEDS = [100_000, 250_000, 500_000, 700_000]
PRIMARY = 100_000


def cast(*args: str) -> str:
    return subprocess.check_output(["cast", *args, "--rpc-url", RPC], text=True).strip()


def main() -> None:
    rss_raw = int(cast("call", RSS, "balanceOf(address)(uint256)", KING).split()[0])
    oracle_raw = int(cast("call", ORACLE, "price()(uint256)").split()[0])
    rss_amt = rss_raw / 1e18
    rss_usd = oracle_raw / 1e24
    coll_usd = rss_amt * rss_usd
    max_b = coll_usd * LLTV

    mkt = cast(
        "call",
        MORPHO,
        "market(bytes32)((uint128,uint128,uint128,uint128,uint128,uint128))",
        MARKET,
    )
    supply_live = int(mkt.strip("()").split(",")[0].split()[0])

    gas_price = int(cast("gas-price").split()[0])
    eth_usd = int(cast("call", ETH_FEED, "latestAnswer()(int256)").split()[0]) / 1e8
    gas_usd = GAS_UNITS * gas_price / 1e18 * eth_usd

    # Live: PA/vault cannot feed this market today (supply dust). Sim assumes S lands.
    live_can = supply_live >= 100_000 * 1e6  # need real liquidity

    def row(S: float) -> dict:
        B = min(S, max_b)
        hf = (coll_usd * LLTV) / B if B else 0.0
        net = B - gas_usd
        return {
            "seed_amount_S": round(S, 2),
            "borrow_amount_B": round(B, 2),
            "net_usdc_in_wallet": round(net, 2),
            "gas_cost": round(gas_usd, 2),
            "hf_after_borrow": round(hf, 2),
            "can_execute_live": "Yes" if live_can and B > 0 and hf >= 1.0 else "No",
            "can_execute_if_seeded": "Yes" if B > 0 and hf >= 1.0 else "No",
        }

    primary = row(PRIMARY)
    scale = [row(s) for s in SEEDS + [max_b]]

    # Scribe return uses live execute flag (Kingdom honesty).
    lines = [
        f"Seed amount (S) ${primary['seed_amount_S']:.2f}",
        f"Borrow amount (B) ${primary['borrow_amount_B']:.2f}",
        f"Net USDC in wallet ${primary['net_usdc_in_wallet']:.2f}",
        f"Gas cost ${primary['gas_cost']:.2f}",
        f"HF after borrow {primary['hf_after_borrow']:.2f}",
        f"Can it execute? {primary['can_execute_live']}",
    ]
    if primary["net_usdc_in_wallet"] > primary["gas_cost"]:
        lines.append(f"Exact net ${primary['net_usdc_in_wallet']:.2f}")
    else:
        lines.append(f"Gap ${primary['gas_cost'] - primary['net_usdc_in_wallet']:.2f}")

    print("\n".join(lines))
    print("--- scale ---")
    for r in scale:
        print(
            f"S ${r['seed_amount_S']:.2f} | B ${r['borrow_amount_B']:.2f} | "
            f"Net ${r['net_usdc_in_wallet']:.2f} | Gas ${r['gas_cost']:.2f} | "
            f"HF {r['hf_after_borrow']:.2f} | Live {r['can_execute_live']} | "
            f"IfSeeded {r['can_execute_if_seeded']}"
        )

    out = {
        "market": MARKET,
        "rss_amount": rss_amt,
        "rss_usd": rss_usd,
        "collateral_usd": round(coll_usd, 2),
        "lltv": LLTV,
        "max_borrow_usd": round(max_b, 2),
        "live_supply_assets_raw": supply_live,
        "primary": primary,
        "scale": scale,
        "scribe_return": lines,
    }
    path = Path("king-pod/deployments")
    path.mkdir(parents=True, exist_ok=True)
    (path / "powerborrow-sim.json").write_text(json.dumps(out, indent=2) + "\n")
    print(f"\n# wrote {path / 'powerborrow-sim.json'}")


if __name__ == "__main__":
    main()
