# PRIME SEED — LIVE (7683 pipe armed)

**Status:** SEEDED · **broken order cancelled** · reopen @ **$4.5M** required  
**Chain:** Base 8453

## Order typo (fixed in scripts)

Live `openOrder` used `4500000000` (= **$4,500** USDC). Correct max for 5M eUSD @ 10% discount:

```text
4500000 * 1e6 = 4500000000000   ($4.5M USDC, 6dp)
```

Broken order (cancel this — unfillable, wastes solver gas):

```text
orderId = 0x2b75086050a42e49192593ad9d97cec9a7f0e829cbf514fce982bf0940a9b88c
maxUsdcIn = 4500000000  ($4,500 — typo)
```

## Cancel + reopen (King GO)

```bash
PRIVATE_KEY=0x… BASE_RPC_URL=https://mainnet.base.org \
  bash king-pod/script/FireCancelReopen7683Cast.sh
```

Or forge:

```bash
KING_GO=1 FIRE_FIX_ORDER=1 OLD_ORDER_ID=0x2b750860… \
  PRIVATE_KEY=0x… forge script script/FireFix7683Order.s.sol:FireFix7683Order \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

## Live stack

| Contract | Address |
|----------|---------|
| CrownPrime7683Fill | `0x4C021c77633e9441be218d2A27a4B40c1Bd720Ab` |
| CrownPrimeCredit | `0xc184A1d2486a24FAb9eB51764c9CF193AE3e6D15` |
| USDCBorrowRouter | `0xA4E04b3160c7ed3cF1c4341DD2f67a06eFF85b6c` |
| CrownLitePsm | `0xC28E7faA9aBb9E6d9627C612F0fb1Bec66E99F6B` |

## Correct fill terms (after reopen)

```text
eusdOut:    5,000,000 eUSD
maxUsdcIn:  4,500,000 USDC (4500000000000 raw)
discount:   10% (maxDiscountBps=1000)
USDC →     CrownPrimeCredit idle → draw → Landing
```

## Post-fill: arm + draw

When `credit.freeUsdc() >= 4500000000000`:

```bash
DRAW_AMT=4500000000000 PRIVATE_KEY=0x… \
  bash king-pod/script/FirePrimeDrawCast.sh
```

## Tests (fork sim)

```bash
cd king-pod && forge test --match-contract FlashFillDraw -vv
```

`FlashFillDrawFork.t.sol` cancels typo order, reopens @ $4.5M, flash-fills on Base fork — **green**.

## Flash-fill engine (optional self-solve)

Deploy + fire: `script/FirePrimeFlashFill.s.sol` · `FirePrimeFlashFillCast.sh`

Physics: flash round-trip (no topUp) fills order + books king debt; **persistent idle** needs external solver fill or `repayTopUp` ≥ flash principal.

**Rotate HOT key** — was used in chat.
