# PCV 700k Seed — King Commands Liquidity

**Verdict:** Not a loan. Protocol Controlled Value + LBP + Morpho book + OTC/ETH rails + RFQ.

## Blueprint corrections (honest wiring)

| Prompt said | Reality |
|-------------|---------|
| CrownOtcEthRail is the Morpho vault | **No** — OTC desk fill `0x6838…029E`. Morpho Vault V2 = `0xB96B…A7b9` (curator=hot) |
| Set 70% LTV on OTC | Morpho RSS market LLTV **77%** immutable; PCV posts book at 77% |
| Polygon zkEVM OEV | Base **ZK gate** `isProven(hot)=true` gates PCV actions |

## Deployed by FirePcvSeed

| Piece | Role |
|-------|------|
| **CrownPcvController** | PCV purse · floor 100k RSS · ZK gate · seeds LBP + Morpho book |
| **CrownRssLbp** | 80/20 → 20/80 over 48h · USDC buys → Landing |
| Vault V2 / yRSS | Already live curator seats · fee → Landing |
| OTC ETH + MultiStable | Already live RFQ rails |

## Execution order (fired)

1. Deposit **200k RSS** PCV (floor 100k + working)
2. Seed LBP **50k RSS** + USDC dust · **48h** weight shift
3. Post **50k RSS** Morpho book (no borrow)
4. RFQ Wintermute/FalconX/Kraken — `MULTI-STABLE-ETH-RFQ.md` / `OTC-ETH-RFQ.md`
5. CCTP / multi-stable rails already armed for ETH·DAI·USDT

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
