# AGENT — Aave-same, King-better (100-word freeze plan)

**Mode:** FREEZE · no builds · no txs · until `FIRE_AGENT=1`

Aave’s agent layer is MCP: read markets, simulate risk, prep unsigned txs—signing stays outside the model. King wants that loop, but better: **CrownKingAgent** with on-chain spend policy (per-tx and daily caps, pause/revoke) plus a hard allowlist to kingdom rails only—mint eUSD, ocean, yRSS curator/PA poke, bond/BAMM, Morpho live-coll or repay-wedge when fuel is named. Same observe→simulate→prepare path as Aave; then King-gated broadcast or capped auto inside law. Refuse gasPark and matched re-borrow. Fork-pass watch mode first. Better = sovereign surfaces + enforceable caps, not a foreign treasury brain. Freeze holds.

```
AAVE=MCP read/simulate/unsigned
KING=same + spend caps + allowlist OUR rails
GATE=FIRE_AGENT=1 · fork watch first · freeze now
```
