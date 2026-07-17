# 5-STEP RAIL — $700k PA formalized

## King order
| Step | Action | Status |
|------|--------|--------|
| 1 | Finish curator package — formalize PA parameters | **DONE** — see below + `CURATOR-LISTING-PACKET.md` |
| 2 | Activate Public Allocator — set `maxIn` to **$700k** | **DONE on King yRSS** (PA allocator=true, RSS maxIn=`700_000e6`) |
| 3 | Pull USDC from another market — **$700k** (not $1) | **BLOCKED** — Gauntlet/Steakhouse RSS `maxIn = 0` (they must accept packet) |
| 4 | Borrow against PoD → KingVault | **ARMED** — fires the second step-3 idle ≥ $700k |

## Formal PA parameters (the ask)
```
MARKET_ID = 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794
maxIn     = 700_000_000000   // $700,000 USDC (6 decimals)
maxOut    = per vault policy // request ≥ $700k on source USDC books
PA        = 0xA090dD1a701408Df1d4d0B85b716c87565f90467
KingVault = 0xA1aFcb46a64C9173519180458C1cF302179c832a
```

### Curator on-chain (targets)
1. `submitCap` / `acceptCap` for RSS market params (USDC/RSS/$1 oracle/AdaptiveCurve/77% LLTV)
2. `PA.setFlowCaps(vault, [{id: MARKET_ID, caps: {maxIn: 700_000e6, maxOut: …}}])`
3. Keep `isAllocator(PA) == true`

### Kingdom fire when maxIn live
```
PA.reallocateTo(vault, withdrawals /* ≥ $700k from their idle markets */, RSS_MARKET)
Morpho.borrow(RSS_MARKET, 700_000e6, 0, KING, KING_VAULT)
```
Contract: `CrownSpoilFire` `0xcFF60…5Fa` (authorized).

## Why step 3 is not $1 theater
Pulling $1 from King yRSS is not the rail. Size is **$700k from foreign vault books** (Gauntlet Prime ~$427M, Steakhouse Prime ~$230M, Steakhouse USDC ~$191M). Those vaults currently: RSS **not enabled**, `maxIn = 0`. Only they can flip that — packet is the key.

## Live gate (Base)
| Vault | RSS enabled | maxIn |
|-------|-------------|-------|
| King yRSS | YES | **$700k** (formalized) |
| Gauntlet USDC Prime | NO | 0 |
| Steakhouse Prime USDC | NO | 0 |
| Steakhouse USDC | NO | 0 |
| Steakhouse HY USDC | NO | 0 |
