# FREEZE — Multi-Asset Hunt (~100 words)

**Mode:** FREEZE · no txs until KING_GO  
**Doctrine:** Loan, don’t sell RSS. Gold vault stays locked. Hunt earns — does not peel PARK/yRSS.

---

## Reality

~$220M yRSS/PARK @ ~100% util = **collateral, not cash**. HOT spendable: USDC≈0, ETH dust, cbBTC dust. Waiting on a USDC buyer is dead. Machines must earn.

## Live gate (honest)

HuntRouter `0xc4c63f8C…4516`: **killSwitch=false · hunter HOT=true** — already armed. Missing: `targetOk` books + 2–3 flash bots with edge.

## Action (on GO)

1. Register targets: ETH / cbBTC / USDC arb — Base + Polygon.  
2. Arm 2–3 flashloan bots → `hunt()`.  
3. **Scoreboard:** HOT ETH + HOT cbBTC (+ USDC if won).  
4. Sweep profits to HOT only — never into gold recycle.

## Result

Vault stays gold. Bots fund the Kingdom from network edge.

```
FREEZE=multi-asset-hunt
HUNT=armed · NEED=targetOk+bots
SCORE=HOT_ETH · HOT_cbBTC
NO=peel-gold · sell-RSS
GO=KING_GO
```
