#!/usr/bin/env python3
"""Whale universe scan — Base Morpho idle across USDC/DAI/EURC/USDbC + kingdom coll doors.
Freeze-safe: read-only. Writes king-pod/deployments/whale-universe.json
"""
from __future__ import annotations

import json
import os
import urllib.request
from pathlib import Path

API = "https://blue-api.morpho.org/graphql"
OUT = Path(__file__).resolve().parents[1] / "deployments" / "whale-universe.json"

EUSD = "0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a".lower()
RSS = "0x7a305D07B537359cf468eAea9bb176E5308bC337".lower()
HOT = "0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1"
LOAN_WANT = {"USDC", "DAI", "USDT", "USDbC", "EURC", "USDe", "USDS"}


def gql(query: str) -> dict:
    req = urllib.request.Request(
        API,
        data=json.dumps({"query": query}).encode(),
        headers={"content-type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def main() -> None:
    q = """
    {
      markets(first: 100, where: { chainId_in: [8453] }, orderBy: SupplyAssetsUsd, orderDirection: Desc) {
        items {
          marketId
          lltv
          state { liquidityAssetsUsd supplyAssetsUsd borrowAssetsUsd }
          loanAsset { symbol address decimals }
          collateralAsset { symbol address }
          reallocatableLiquidityAssets
          supplyingVaults { name address }
        }
      }
    }
    """
    d = gql(q)
    items = d["data"]["markets"]["items"]
    items.sort(key=lambda m: m["state"]["liquidityAssetsUsd"] or 0, reverse=True)

    deep = []
    kingdom_coll = []
    multi_stable = []

    for m in items:
        la = m["loanAsset"]
        ca = m["collateralAsset"] or {}
        liq = m["state"]["liquidityAssetsUsd"] or 0
        row = {
            "marketId": m["marketId"],
            "loan": la["symbol"],
            "loanAddress": la["address"],
            "decimals": la["decimals"],
            "coll": ca.get("symbol"),
            "collAddress": ca.get("address"),
            "idleUsd": liq,
            "supplyUsd": m["state"]["supplyAssetsUsd"],
            "lltv": m["lltv"],
            "vaults": len(m.get("supplyingVaults") or []),
            "reallocatable": m.get("reallocatableLiquidityAssets"),
        }
        if liq >= 50_000:
            deep.append(row)
        if (ca.get("address") or "").lower() in (EUSD, RSS):
            kingdom_coll.append(row)
        if la["symbol"] in LOAN_WANT and liq >= 1_000:
            multi_stable.append(row)

    board = {
        "chain": "base",
        "hot": HOT,
        "thesis": "Borrow foreign idle vs kingdom/bluechip coll — do not mint Circle",
        "deepIdleGe50k": deep[:40],
        "multiStableIdleGe1k": multi_stable[:40],
        "kingdomCollateralMarkets": kingdom_coll,
        "fire": {
            "createEusdDoors": "KING_GO=1 forge script script/CreateEusdLoanMarkets.s.sol:CreateEusdLoanMarkets --rpc-url $BASE_RPC_URL --broadcast --slow",
            "deployHarvest": "KING_GO=1 forge script script/FireWhaleHarvest.s.sol:FireWhaleHarvest --rpc-url $BASE_RPC_URL --broadcast --slow",
            "vacuum": "KING_GO=1 VACUUM=1 HARVEST=0x… forge script script/FireWhaleHarvest.s.sol:FireWhaleHarvest --rpc-url $BASE_RPC_URL --broadcast --slow",
        },
    }

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(board, indent=2) + "\n")
    print(f"wrote {OUT}")
    print(f"deep>={50000}: {len(deep)}  multi-stable: {len(multi_stable)}  kingdom-coll: {len(kingdom_coll)}")
    print("TOP 10 idle:")
    for r in deep[:10]:
        print(f"  ${r['idleUsd']:>12,.0f}  {r['loan']:5}/{r['coll']}  vaults={r['vaults']}  {r['marketId'][:18]}…")


if __name__ == "__main__":
    main()
