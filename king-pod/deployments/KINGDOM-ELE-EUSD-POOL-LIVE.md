# Kingdom ELE/eUSD pool — LIVE (own inventory)

**Doctrine:** No outside USDC. No waiting. Seed a real pool from ELE.  
**Fired:** 2026-07-29 · Base hot

## What we built

| Leg | Amount |
|--|--|
| ELE in pool | **500,000 ELE** |
| eUSD in pool | **500,000 eUSD** |
| Notional | **~$1,000,000** two-sided at $1 |
| Fee tier | 0.3% |
| Price | 1:1 init |

## Machine

1. Deploy ELE CDP with **treasury = hot** (so mint is LPable)
2. Lock **1,000,000 ELE** in CDP → mint **500,000 eUSD** (HF = 2.0)
3. Create + init UniV3 ELE/eUSD pool
4. LP full range: 500k ELE + 500k eUSD

## Addresses

| Piece | Address |
|--|--|
| Pool | `0x7d41ac987F8952617cca165E7D93576107ed1863` |
| CDP (treasury=hot) | `0xda19793ad426E05213C7B38B85028811A80177Fa` |
| eUSD | `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a` |
| LP NFT | tokenId `5693036` (hot) |

## Truth

This is a **kingdom-asset pool** (ELE ↔ eUSD), not a USDC payroll sink. It is real depth from inventory we hold. USDC still requires a convert leg later; this removes the “dust market” problem between kingdom units.
