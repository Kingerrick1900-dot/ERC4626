#!/usr/bin/env python3
"""Peapods LVF / self-lend simulation for RSS on Base — numbers only."""
from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

RPC = os.environ.get("BASE_RPC") or os.environ.get("BASE_RPC_URL") or "https://mainnet.base.org"

RSS = "0x7a305D07B537359cf468eAea9bb176E5308bC337"
USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
UNI_FACTORY = "0x33128a8fC17869897dcE68Ed026d694621f6FDfD"
MORPHO_ORACLE = "0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e"
ETH_USD_FEED = "0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70"

# Peapods liquidation LTV (docs)
LLTV = 0.8333
# Atomic LVF wrapper gas (flash→supply→LP→collateral→borrow→repay)
GAS_UNITS = 1_200_000
RSS_INPUT = 2_500_000
FLASH_PRIMARY = 500_000
FLASH_SCALE = [125_000, 500_000, 1_000_000, 2_000_000]


def cast(*args: str) -> str:
    return subprocess.check_output(["cast", *args, "--rpc-url", RPC], text=True).strip()


def live_checks() -> dict:
    pools = {}
    for fee in (100, 500, 3000, 10000):
        addr = cast("call", UNI_FACTORY, "getPool(address,address,uint24)(address)", RSS, USDC, str(fee)).split()[0]
        pools[str(fee)] = addr
    oracle_raw = int(cast("call", MORPHO_ORACLE, "price()(uint256)").split()[0])
    # Morpho: (1e18 RSS * price / 1e36) / 1e6 USDC decimals → usd = oracle_raw / 1e24
    rss_usd = oracle_raw / 1e24
    gas_price = int(cast("gas-price").split()[0])
    eth_usd = int(cast("call", ETH_USD_FEED, "latestAnswer()(int256)").split()[0]) / 1e8
    uni_live = any(int(a, 16) != 0 for a in pools.values())
    return {
        "uni_v3_rss_usdc_pools": pools,
        "uni_v3_live": uni_live,
        "peapods_rss_pod": None,
        "rss_usd_morpho_oracle": rss_usd,
        "gas_price_wei": gas_price,
        "eth_usd": eth_usd,
        "can_create_peapods_pod": False,  # needs Uni V3 + Chainlink; both missing for RSS
        "can_execute_live": False,
    }


def simulate(rss_amt: float, flash: float, rss_usd: float, gas_usd: float) -> dict:
    rss_side = rss_amt * rss_usd
    lp_usd = flash + rss_side
    debt = flash  # borrow exact flash to repay
    ltv = debt / lp_usd if lp_usd else 0.0
    hf = (lp_usd * LLTV) / debt if debt else 0.0
    max_flash = (LLTV / (1.0 - LLTV)) * rss_side
    # Peapods self-lend: borrow == flash → net USDC after repay = $0 by design
    net_after = 0.0
    # 100% util until external supply; releaseCollateral/redeem cannot pull idle USDC
    exit_net = 0.0
    gap = round(gas_usd - net_after, 2)
    return {
        "rss_amount": rss_amt,
        "rss_usd": rss_usd,
        "rss_side_usd": round(rss_side, 2),
        "flash_usdc": flash,
        "lp_usd": round(lp_usd, 2),
        "debt_usdc": debt,
        "ltv": round(ltv, 6),
        "max_flash_before_liq": round(max_flash, 2),
        "net_usdc_after_loop": round(net_after, 2),
        "gas_cost_usd": round(gas_usd, 2),
        "hf_after_opening": round(hf, 2),
        "exit_net_usdc": round(exit_net, 2),
        "gap_vs_gas": gap,
        "can_execute": "No",
    }


def main() -> None:
    live = live_checks()
    gas_eth = GAS_UNITS * live["gas_price_wei"] / 1e18
    gas_usd = gas_eth * live["eth_usd"]
    rss_usd = live["rss_usd_morpho_oracle"]

    primary = simulate(RSS_INPUT, FLASH_PRIMARY, rss_usd, gas_usd)
    scale = [simulate(RSS_INPUT, f, rss_usd, gas_usd) for f in FLASH_SCALE]

    # Exact Scribe return block
    lines = [
        f"Net USDC after loop ${primary['net_usdc_after_loop']:.2f}",
        f"Gas cost ${primary['gas_cost_usd']:.2f}",
        f"HF after opening {primary['hf_after_opening']:.2f}",
        f"Exit net USDC ${primary['exit_net_usdc']:.2f}",
        f"Can it execute? {primary['can_execute']}",
        f"Gap ${primary['gap_vs_gas']:.2f}",
    ]
    print("\n".join(lines))

    out = {
        "chain": "base",
        "protocol": "Peapods LVF self-lend (sim)",
        "live": live,
        "primary_flash_500k": primary,
        "scale": scale,
        "scribe_return": lines,
    }
    path = Path("deployments") if Path("deployments").is_dir() else Path(".")
    path = path / "peapods-lvf-sim.json"
    # Prefer king-pod/deployments if present
    kp = Path("king-pod/deployments")
    if kp.is_dir():
        path = kp / "peapods-lvf-sim.json"
    path.write_text(json.dumps(out, indent=2) + "\n")
    print(f"\n# wrote {path}", flush=True)


if __name__ == "__main__":
    main()
