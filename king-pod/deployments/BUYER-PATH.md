# Buyer path — the only way $10 (or any oracle) prints cash

## Physics (locked)

| Play | Wallet USDC |
|--|--|
| New Morpho market + inflated oracle, **empty** | **$0** — borrow reverts, no idle |
| Flash / self-seed that market, then borrow | **$0** — circular; repay eats the borrow |
| **External USDC** seeds the market (or buys ELE), then borrow/sell | **Yes** — real counterparty dollars |

A $10 oracle is a **multiplier on collateral math**. It does not mint USDC. Morpho borrow always needs **idle loan tokens in that market**.

Refuse: paths that drain unaware third-party suppliers via a knowingly fake oracle. Kingdom does not build that.

## What the king has now (Base)

| Asset | Amount | Where |
|--|--|
| USDC | **$1.00** liquid | hot `0x6708…a7d1` |
| ELE | **~14.0M** | hot |
| ELE/USDC UniV3 | pool [`0x4615a3E4…7410`](https://basescan.org/address/0x4615a3E473944C12bDF4e1E3d1ea5e5968397410) · ~$60 depth | fee 3000 |
| yELE-K claim | ~**$15.82** residual dust | after pot unlock |
| Landing | frozen | `LANDING-FROZEN.md` |

## Honest cash doors (ranked)

1. **OTC ELE → USDC** — buyer wires USDC to hot; king sends ELE. Fastest ops float.  
2. **Deepen the public pool** — buyer (or king later) adds USDC/ELE LP; market can sell ELE.  
3. **Foreign Morpho idle** — curator sets `maxIn` on ELE/USDC 77% with real vault supply (CashHunt). Not oracle theater.  
4. **Post-seed leverage only** — *after* real USDC sits in a kingdom market, borrow against posted ELE. Oracle choice then sizes LTV; still not a printer without seed.

## OTC ask (copy/paste)

```
Kingdom ELE OTC — Base
Token: ELE 0x50639C42E2FFDEC4F68FB468968a55b3Af944583 (8 decimals)
Seller: 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
Settle: USDC 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 → seller hot
Public rail: UniV3 ELE/USDC 0x4615a3E473944C12bDF4e1E3d1ea5e5968397410 (thin — OTC preferred for size)
Size: start $5k–$50k USDC · larger by tranche
```

## $10 market — when (not if empty)

Only scaffold a $10 / high-LLTV market **after** a named USDC seed is on Morpho in that market. Until then: no createMarket fire, no borrow script, no “print” narrative.
