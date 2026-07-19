# BRETT market activated on yRSS

**Tx bundle:** see `broadcast/ActivateBrettMarket.s.sol/8453/run-latest.json`

## What fired
1. **Supply queue → BRETT first** — new USDC deposits into yRSS deploy to BRETT immediately.
2. **Reallocate** idle + cbBTC dust → BRETT market (Morpho supply now live on BRETT).

## Constraint (honest)
RSS market free liquidity = **0** (100% util). The ~$546 already in RSS **cannot** move until someone repays and frees liquidity. King is curator — no foreign PA needed for this path.

## Live
| Field | Value |
|--|--|
| BRETT market | `0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16` |
| yRSS queue[0] | BRETT |
| BRETT supply (post-activate) | dust seed from idle/cbBTC — path proven |
| Next deposits | hit BRETT first up to $2M cap / $700k PA |
