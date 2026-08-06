# Protocol lock — Venus / Kamino Multiply (+ Seamless close law)

King order: one perfected pattern. Use free RSS. Size **$700k**. Engineer past empty depth.

## The protocol

**Venus `LeverageStrategiesManager` / Kamino Multiply** (Pendle PT flash is the same shape).  
Close law matches **Seamless `LeverageRouter`**: debt on the router repays the Morpho flash.

1. Pull **equity** = free RSS from hot (`collateralFromSender`)
2. Morpho `flashLoan` USDC ($700k)
3. Engineer lending depth in-tx (`repay` manufactures idle — Aero $0.67 is not a veto)
4. **Borrow to router** repays the flash
5. **Seed = Morpho position**. Surplus above flash → Landing

See `VENUS-MULTIPLY-700K.md`.

## Chassis

| Contract | Role |
|----------|------|
| `CrownSeamlessMission.sol` | Seamless settle law |
| `CrownMissionComplete.sol` | Proto/unlock companions (same close idea) |

```text
seamlessClose(flash, equityRss)   // close engineered; surplus→Landing (0 on self-match)
seamlessLand(flash, want, equity) // same; tries want surplus when idle allows
```

## Fork

```bash
cd king-pod
forge test --match-contract SeamlessMissionFork -vv --fork-url $BASE_RPC_URL
forge test --match-contract MissionCompleteFork -vv --fork-url $BASE_RPC_URL
```

## King — free tokens? (ask first — not broadcast)

Live board:

| Bag | Amount | Need to free? |
|-----|--------|----------------|
| **Free RSS on hot** | **~9.76M** already | **No** — Seamless equity leg can use this now |
| Morpho posted coll | **220k RSS** vs ~$200.8M self-matched book | **Only if you order it** |

**Chief will not free the 220k / unwind the $200.8M book unless King says the word**  
(`FREE THE BOOK` / `FREE THE 220k`).

Why free is optional, not the USDC fix:

- Seamless **surplus USDC** comes from **market idle / foreign lenders**, not from posting more RSS.
- This RSS/$1200 book is still **~100% util self-matched** → after Seamless close, surplus to Landing = **$0** (flash size consumes the manufactured idle).
- Freeing the last 220k unlocks tokens (FLASH-FREE shape). It does **not** mint Circle USDC onto Landing by itself.

## What completes Landing +$700k under Seamless law

Same as Seamless in production: the debt market must have **real USDC liquidity** beyond the flash rematch — Public Allocator / foreign vault idle into the market, then `seamlessLand` surplus ≥ $700k, **or** equity into a **foreign** USDC market that already has idle (WETH/cbETH path).

Scribe now: **loan closes** with zero hot USDC prefund (Seamless-perfect).  
Scribe next: Landing Δ = $700k when idle/PA/foreign leg is live — still Seamless surplus, not “close capital on hot.”
