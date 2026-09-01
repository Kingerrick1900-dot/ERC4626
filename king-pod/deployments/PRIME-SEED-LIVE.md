# PRIME SEED — LIVE (7683 pipe armed)

# PRIME SEED — LIVE

**Status:** Idle tap live · flash engines **revoked** · new 7683 order **open for external fill only**  
**Chain:** Base 8453

## What was wrong

Self-flash-fill [`0x174cc502…`](https://basescan.org/tx/0x174cc5025915fdd4c4715375c9b5baf045acad2dfe1c693b2cae5f5bb90e486b) closed the $4.5M order and booked **$4.5M king debt** while putting **$0** in `credit.freeUsdc()`. Morpho flash was repaid from credit. That is not idle.

Flash operators on credit are now **false**.

## Idle machine (this is the path)

| Piece | Address |
|-------|---------|
| **CrownPrimeIdleTap** | `0x23EF8f1D436ec96fd82d5F85D05AF34d8f1b17e5` |
| eUSD $1 oracle | `0x44bc82a9ADaF15edCa1bc0030Bdf7500af5CC750` |
| Morpho eUSD/USDC market | `0x5d46483aa8dda7876be78f42f1fe2c93856918e26ed027ad4bb551cb74a68366` |
| eUSD coll posted | **20M** (HOT) |
| yRSS cap + PA maxIn | **$50M** on that market |

`IdleTapFork` (Base fork): seed $100k USDC into the book → `tapEusd` → **credit.freeUsdc() += $100k**. Proven.

When any USDC is supplied to that Morpho book (solver, PA, yRSS, depositor):

```bash
cast send 0x23EF8f1D436ec96fd82d5F85D05AF34d8f1b17e5 "tapEusd(uint256)" 0
```

USDC stays in `CrownPrimeCredit`. No flash repay.

## External 7683 order (do not self-fill)

```text
orderId   = 0xf686d8b64760ef692e4edbd480a3ca7db225a21a16eb60bfb7c99baa231631e9
maxUsdcIn = 4500000000000
Fill      = 0x4C021c77633e9441be218d2A27a4B40c1Bd720Ab
open tx   = 0xe0246c6ed8c90ede496869552a95e3ed74bc53c7a53e0012e8b776eb11650cad
```

Solver USDC → credit idle → `FirePrimeDrawCast.sh`.

## Flash fill (self-solve — fired) — DO NOT REPEAT

| Item | Value |
|------|-------|
| **CrownPrimeFlashFillDraw** | `0xf84af71DE78AaCddc4201F5dc8c9238C69851429` |
| **flashFill tx** | [`0x174cc502…e486b`](https://basescan.org/tx/0x174cc5025915fdd4c4715375c9b5baf045acad2dfe1c693b2cae5f5bb90e486b) |
| orderId | `0x2c85b27d5a04300779222173c2add2a7d71e366734c5b8aab435fba579f5eada` |
| order status | **2 (filled)** · filledUsdc = **4500000000000** |
| HOT eUSD | +5M (from fill) |
| credit.debtOf(HOT) | **$4.5M** |
| credit idle | **0** (flash repaid via borrow — physics) |
| Landing USDC | **0** (draw needs idle; use topUp path or external supply) |
| router.armed | **true** |

## Cancel + reopen txs (prior)

| Step | Tx | Result |
|--|--|--|
| **cancel** broken $4,500 order | [`0x9b37757b…c79c`](https://basescan.org/tx/0x9b37757beefe3ff60e19f660f8076e02ece80fe1a57727461bff42f1ee44c79c) | status=3 cancelled |
| `setFees(1000,0)` | [`0xc8e217b4…5396`](https://basescan.org/tx/0xc8e217b41aaca375107fe3c34a61c691b4ea0a3299a19b7bdbefb9650c945396) | protocolFeeBps=0 |
| **openOrder** 5M @ **$4.5M** | [`0x57495f3b…34b7`](https://basescan.org/tx/0x57495f3b6f11205ff59ade720cecbb80ad6cfec8149d69a4cf74bbfc732434b7) | status=open |

## Order (solver fill this)

```text
orderId = 0xf686d8b64760ef692e4edbd480a3ca7db225a21a16eb60bfb7c99baa231631e9
eusdOut = 5,000,000 eUSD
maxUsdcIn = 4500000000000
Fill:    0x4C021c77633e9441be218d2A27a4B40c1Bd720Ab
Pay:     ≥ $4,050,000 USDC (10% discount floor) · ≤ $4,500,000 max
Gets:    5,000,000 eUSD → HOT
USDC →  CrownPrimeCredit idle (then draw)
```

## Cancelled typo order (do not fill)

```text
orderId = 0x2b75086050a42e49192593ad9d97cec9a7f0e829cbf514fce982bf0940a9b88c  (status=3)
maxUsdcIn was 4500000000 = $4,500 only — 1000× typo
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

When `credit.freeUsdc() > 0` (external solver / topUp flash):

```bash
DRAW_AMT=4500000000000 PRIVATE_KEY=0x… \
  bash king-pod/script/FirePrimeDrawCast.sh
```

**Flash round-trip (no topUp):** order filled + king debt booked; idle returns to 0 after Morpho repay. For **Landing USDC**, use `repayTopUp=4500000000000` on `flashFillAndDraw` or inbound solver fill.

## Flash engine deploy

```bash
KING_GO=1 FIRE_FLASH_FILL=1 PRIVATE_KEY=0x… \
  forge script script/FirePrimeFlashFill.s.sol:FirePrimeFlashFill \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

Live engine: `0xf84af71DE78AaCddc4201F5dc8c9238C69851429` — do **not** call `setRepayRails(yRSS)` without yRSS share approval.

## Tests (fork sim)

```bash
cd king-pod && forge test --match-contract FlashFillDraw -vv
```

`FlashFillDrawFork.t.sol` cancels typo order, reopens @ $4.5M, flash-fills on Base fork — **green**.

## Flash-fill engine (optional self-solve)

Deploy + fire: `script/FirePrimeFlashFill.s.sol` · `FirePrimeFlashFillCast.sh`

Physics: flash round-trip (no topUp) fills order + books king debt; **persistent idle** needs external solver fill or `repayTopUp` ≥ flash principal.

**Rotate HOT key** — was used in chat.
