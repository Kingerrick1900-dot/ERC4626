# PRIME SEED — LIVE

**Status:** Flash mess contained · router **disarmed** · idle tap live · 7683 open for **external fill only**  
**Chain:** Base 8453

## Live state (now)

| Metric | Value |
|--------|-------|
| `credit.freeUsdc()` | **0** |
| `credit.debtOf(HOT)` | **$4,500,000** (phantom debt from self-flash) |
| `coll.reservedDebtUsd6` | **$4,500,000** |
| Landing USDC | **0** |
| `router.armed` | **false** (disarmed tx [`0x5f6c0d31…`](https://basescan.org/tx/0x5f6c0d31ce132db5b889d6d7c299cada47139ea728bd39aab726a91ee358e340)) |
| Flash engine operator | **false** |
| Morpho eUSD/USDC book idle | **0** |

**Clearing the $4.5M debt** requires **$4.5M real USDC** into `CrownPrimeCredit.repay()`. Flash cannot undo this — the USDC left credit to repay Morpho.

HOT received **+5M eUSD** from the bad fill (buffer). Debt is real until repaid.

## What went wrong (do not repeat)

Self-flash-fill [`0x174cc502…`](https://basescan.org/tx/0x174cc5025915fdd4c4715375c9b5baf045acad2dfe1c693b2cae5f5bb90e486b):

1. Morpho flash → 7683 fill → USDC briefly in credit  
2. Engine `operatorBorrowTo` → USDC out to repay flash  
3. **Result:** order filled, **$4.5M king debt**, **`credit.freeUsdc() = 0`**, Landing **$0**

Flash operators revoked. Cast scripts **disabled**. Forge deploy requires `I_ACCEPT_FLASH_DEBT=1`.

## Idle machine (correct path)

| Piece | Address |
|-------|---------|
| **CrownPrimeIdleTap** | `0x23EF8f1D436ec96fd82d5F85D05AF34d8f1b17e5` |
| eUSD $1 oracle | `0x44bc82a9ADaF15edCa1bc0030Bdf7500af5CC750` |
| Morpho eUSD/USDC market | `0x5d46483aa8dda7876be78f42f1fe2c93856918e26ed027ad4bb551cb74a68366` |
| eUSD coll posted | **20M** (HOT) |

When USDC is supplied to that Morpho book (solver, PA, depositor):

```bash
cast send 0x23EF8f1D436ec96fd82d5F85D05AF34d8f1b17e5 "tapEusd(uint256)" 0 \
  --rpc-url $BASE_RPC_URL --private-key $PRIVATE_KEY
```

USDC stays in `CrownPrimeCredit`. **No flash repay.**

`IdleTapFork`: seed $100k → tap → **credit.freeUsdc() += $100k** — green.

## External 7683 order (solver fill — creates real idle)

```text
orderId   = 0xf686d8b64760ef692e4edbd480a3ca7db225a21a16eb60bfb7c99baa231631e9
maxUsdcIn = 4500000000000   ($4.5M — NOT 4500000000)
Fill      = 0x4C021c77633e9441be218d2A27a4B40c1Bd720Ab
open tx   = 0xe0246c6ed8c90ede496869552a95e3ed74bc53c7a53e0012e8b776eb11650cad
```

Solver USDC → credit idle → arm + draw (only when idle > 0).

## Post-idle: arm + draw

```bash
DRAW_AMT=4500000000000 PRIVATE_KEY=0x… \
  bash king-pod/script/FirePrimeDrawCast.sh
```

Script refuses if `credit.freeUsdc() == 0`.

## Disarm (safe default while no idle)

```bash
PRIVATE_KEY=0x… bash king-pod/script/FirePrimeDisarmCast.sh
```

## Disabled scripts (refuse to run)

- `FirePrimeFlashFillCast.sh`
- `FirePrimeFlashGuaranteedCast.sh`
- `FirePrimeFlashFill.s.sol` deploy/live unless `I_ACCEPT_FLASH_DEBT=1`

## Live stack

| Contract | Address |
|----------|---------|
| CrownBoundLandingCollateral | `0x99bE1Ec7Dba573da84cF42663B60A27108B6c3e8` |
| CrownPrime7683Fill | `0x4C021c77633e9441be218d2A27a4B40c1Bd720Ab` |
| CrownPrimeCredit | `0xc184A1d2486a24FAb9eB51764c9CF193AE3e6D15` |
| USDCBorrowRouter | `0xA4E04b3160c7ed3cF1c4341DD2f67a06eFF85b6c` |
| CrownLitePsm | `0xC28E7faA9aBb9E6d9627C612F0fb1Bec66E99F6B` |
| SelfRepayingTreasury | `0xA1215D21eBC646F609d2CcAAc0cD4E00bF0ebd97` |
| Landing | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| HOT | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |

## Repay debt (when USDC arrives)

```bash
# approve credit, then:
cast send 0xc184A1d2486a24FAb9eB51764c9CF193AE3e6D15 \
  "repay(uint256)" 4500000000000 \
  --rpc-url $BASE_RPC_URL --private-key $PRIVATE_KEY
```

Partial repay works — any USDC reduces `debtOf(HOT)` and `reservedDebtUsd6`.

## Tests

```bash
cd king-pod && forge test --match-contract IdleTap -vv
```

**Rotate HOT key** — was used in chat.
