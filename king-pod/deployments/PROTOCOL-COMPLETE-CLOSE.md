# Protocol lock — Seamless LeverageRouter

King order: find **one** protocol that closed to perfection. Use that.

## The protocol

**Seamless `LeverageRouter`**  
https://github.com/seamless-protocol/leverage-tokens/blob/main/src/periphery/LeverageRouter.sol

Settle law (deposit) — copied into `CrownSeamlessMission`:

1. Pull **equity** collateral from sender (`collateralFromSender`)
2. Morpho `flashLoan` the debt asset
3. Work leg (post equity / shape the book)
4. **Debt on the router repays the flash** ← that is close capital (engineered, not hot buffer)
5. **Surplus** debt above the flash amount → sender (we credit **Landing**)

Seamless never asks the EOA for a second USDC pile to “close.” Close = borrow/debt sitting on the router.

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
