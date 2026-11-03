# OceanArb Keeper

Polls Base / Polygon / Scroll `OceanArb` sleeves. Rotates when edge ≥ 0.2%. Pushes excess to ColdBuffer.

```bash
npm i
export OCEAN_BASE=0x...
export OCEAN_POLYGON=0x...   # optional
export OCEAN_SCROLL=0x...    # optional
export PRIVATE_KEY=0x...     # HOT — one wallet
DRY_RUN=1 npm start          # read + log
npm start                    # live rotate
```

Requires each OceanArb `armed=true`, router set, and seeded USDC POL.
