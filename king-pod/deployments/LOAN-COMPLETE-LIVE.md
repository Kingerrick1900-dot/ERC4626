# Loan / Ops — Status

Morpho-native path (collateral → borrow → Landing KEEP): `MORPHO-LINKS.md`

| Fact | Live |
|--|--|
| Morpho ELE debt | ~$14.0M |
| Ops USDC | ~$5.65 |
| Idle ELE/USDC | $0 (self-loop) |
| Posted coll headroom | ~$1.40M |
| Free Elepan capacity | ~$43.1M if idle opens |

```bash
# when idle > 0 — USDC to Landing, no vault
KING_GO=1 FIRE_MORPHO_OPS=1 BORROW_USDC=500000000000 \
  forge script script/FireMorphoOpsDraw.s.sol:FireMorphoOpsDraw \
  --rpc-url $BASE_RPC --broadcast --slow
```
