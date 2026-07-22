# PCV 700k Seed — King Commands Liquidity

**Verdict:** Not a loan. Protocol Controlled Value + LBP + Morpho book + OTC/ETH rails + RFQ.

## Blueprint corrections (honest wiring)

| Prompt said | Reality |
|-------------|---------|
| CrownOtcEthRail is the Morpho vault | **No** — OTC desk fill `0x6838…029E`. Morpho Vault V2 = `0xB96B…A7b9` (curator=hot) |
| Set 70% LTV on OTC | Morpho RSS market LLTV **77%** immutable; PCV posts book at 77% |
| Polygon zkEVM OEV | Base **ZK gate** `isProven(hot)=true` gates PCV actions |

## Deployed + funded (LIVE)

| Piece | Address / state |
|-------|-----------------|
| **CrownPcvController** | `0x1B61Da8F654569F48AC7E2752BD3d8016ED4fcb9` · PCV **100k RSS** floor |
| **CrownRssLbp** | `0x70dcAb53a156936A9fBAf7785176BebDfd057012` · **live** · **50k RSS** · 48h 80→20 |
| Morpho book | **50k RSS** posted (no borrow) |
| Vault V2 / yRSS | Curator seats live · fee → Landing |
| OTC ETH + MultiStable | 700k RSS each · RFQ ready |

## Execution order (fired)

1. Deposit **200k RSS** PCV ✅  
2. Seed LBP **50k RSS** + \$1 USDC · **48h** ✅  
3. Post **50k RSS** Morpho book (no borrow) ✅  
4. RFQ — send `RFQ-EMAIL-ETH.md`  
5. CCTP / multi-stable rails armed for ETH·DAI·USDT ✅

## Success metrics (feed)

| Metric | Target |
|--------|--------|
| Ethereum stables/ETH via RFQ | **$500k–$700k** |
| LBP price discovery | → ≥ $0.95/RSS path |
| Morpho book | PCV collateral live |
| Yield | yRSS 10% fee → Landing |

## Fire

```bash
KING_OK=1 FIRE_PCV_SEED=1 forge script script/FirePcvSeed.s.sol \
  --rpc-url $BASE_RPC --broadcast --chain 8453
```

The king does not borrow. The king seeds PCV, bootstraps the book, and fills via RFQ.
