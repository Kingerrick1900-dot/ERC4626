# $500k — Prove → Match → Draw

**Primary (elite):** ZK-proven **$1M** liquidity matches **$500k** into credit → Landing.  
See `PROVE-LIQUIDITY-MATCH.md` + `zk-liquidity-match.json`.

```text
verify isProven($1M) → supply(500k) into 0xc415…d936 → poke AutoDraw 0xB648…8a23 → Landing
```

```bash
KING_GO=1 FIRE_ZK_CREDIT=1 ASK_USDC=500000000000 \
  forge script script/FireZkCreditDraw.s.sol:FireZkCreditDraw \
  --rpc-url $BASE_RPC --broadcast --slow
```

Auto-draw: `0xB6481E2ca95c14BC47B29b60fec6eF7e4A398a23`
