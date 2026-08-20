#!/usr/bin/env python3
"""Mint sizing for Liquity-pattern RSS trove — 100M default. Morpho book untouched."""
import os

MINT = int(os.environ.get("MINT_EUSD", str(100_000_000 * 10**18)))
PX = 1200  # USD per RSS
LTV = float(os.environ.get("LTV", "0.77"))  # 0.77=CR~130%, 0.909=CR110%, 0.667=CR150%
BUFFER = float(os.environ.get("BUFFER", "1.20"))
FREE_RSS = float(os.environ.get("FREE_RSS", "14730000"))  # ~live after 200M signal
MORPHO_COLL = float(os.environ.get("MORPHO_COLL", "250000"))

mint_usd = MINT / 1e18
coll = (mint_usd / (PX * LTV)) * BUFFER
cr = 1.0 / LTV

print(f"mintEusd={mint_usd:,.0f}")
print(f"oracleUsdPerRss={PX}")
print(f"ltv={LTV} (CR≈{cr*100:.1f}%)")
print(f"buffer={BUFFER}")
print(f"collRssNeeded={coll:,.0f}")
print(f"freeRssApprox={FREE_RSS:,.0f}")
print(f"morphoCollLocked={MORPHO_COLL:,.0f} (DO NOT TOUCH — $200M signal)")
print(f"headroomAfter={FREE_RSS - coll:,.0f}")
print(f"FITS={'YES' if FREE_RSS >= coll else 'NO'}")
print("ACTION= KING_OK=1 FIRE_TROVE=1 forge script FireRssTroveMint (after Peapods+Merkl order or parallel mint rail)")
