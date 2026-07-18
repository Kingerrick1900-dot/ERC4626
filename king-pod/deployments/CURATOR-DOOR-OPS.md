# Curator door — 4-step ops (LIVE)

**Date:** 2026-07-18 UTC  
**Market:** `0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794`  
**KingVault:** `0xA1aFcb46a64C9173519180458C1cF302179c832a`

| Step | Order | Status |
|--|--|--|
| 1 | Gauntlet / Steakhouse allocate (`maxIn` > 0) | **PACKET READY + ORACLE LOCKED** — forum posts paste-ready; depth gap named |
| 2 | Borrow external USDC → KingVault | **ARMED** — `FirePositionSeed700k` + `watch_maxin_fire.py` |
| 3 | Ops: non-posted inventory → stables | **DONE** — loop USDC swept to KingVault |
| 4 | Flash only with named repay source | **POLICY LOCKED** — see `FLASH-POLICY.md` |

---

## Step 1 — Unlock (curator allocation)

### Oracle (Morpho-native FixedOracle — objection removed)
| Field | Value |
|--|--|
| Contract | Morpho FixedOracle `0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e` |
| `price()` | `1e24` (= **$1 / RSS**, Morpho oracle scale) |
| Owner | **`0x…dEaD`** — `setPrice` permanently dead |
| Lock tx | `0x7b35b2769fb3a05d6962de25e8ab6cf07e7da0d90d64d237eddd8d317bde4726` |
| Market id | **unchanged** (no oracle swap → no new market / PoD preserved) |

This is Morpho’s native fixed-price oracle pattern. Admin key burned. “Bad oracle / mutable price” is closed.

### Collateral liquidity depth (honest gate)
| Venue | RSS/USDC | RSS/WETH |
|--|--|--|
| Uniswap V3 (all fees) | **none** | **none** |
| Uniswap V2 | **none** | **none** |
| Aerodrome CL | **none** | **none** |
| DexScreener / GeckoTerminal | **0 pairs** | **0 pairs** |

**Fact:** RSS has **no verifiable secondary-market depth** today. That is the remaining curator objection after oracle lock.

**Remediation (parallel track):** seed UniV3 RSS/USDC 1% (or Aero CL) with real USDC once Step 2/3 runway exists — see `RSS-LIQUIDITY-DEPTH-PLAN.md`. Ask curators for **High Yield / Core** first, not Prime blue-chip.

### Risk parameters (submit these)
| Param | Value |
|--|--|
| Loan | USDC `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| Collateral | RSS `0x7a305D07B537359cf468eAea9bb176E5308bC337` |
| Oracle | FixedOracle `$1` (owner dead) |
| IRM | AdaptiveCurveIRM `0x46415998764C29aB2a25CbeA6254146D50D22687` |
| LLTV | **77%** |
| Ask supply cap (initial) | **$700,000** USDC |
| PA `maxIn` | **`700_000e6`** |
| PA | `0xA090dD1a701408Df1d4d0B85b716c87565f90467` |

### Live PoD (why idle USDC earns here)
| Metric | Live |
|--|--|
| Supply ≈ Borrow | **~$9.25M** |
| Utilization | **~100%** |
| RSS collateral posted | **~18.5M** |
| Health factor | **~1.54** |
| Scale tx | `0x00d9ce8219dafc0697b9cd487c9327660a405ef498894ab551819f4d8bb6dba0` |

### Target vaults (current gate)
| Vault | Address | RSS enabled | maxIn |
|--|--|--|--|
| Gauntlet USDC Prime | `0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61` | NO | 0 |
| Steakhouse Prime USDC | `0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2` | NO | 0 |
| Steakhouse USDC | `0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183` | NO | 0 |
| Steakhouse High Yield USDC | `0xBEEFA7B88064FeEF0cEe02AAeBBd95D30df3878F` | NO | 0 |

**Primary ask:** Steakhouse **High Yield** + any Gauntlet **Core/Frontier** on Base — not Prime until RSS DEX depth exists.  
**Forum paste:** `FORUM-POST-STEAKHOUSE.md`, `FORUM-POST-GAUNTLET.md`  
**Channels:** https://forum.morpho.org/c/vaults/steakhouse-financial/18 · https://forum.morpho.org/c/vaults/gauntlet/19

---

## Step 2 — Borrow into KingVault (armed)

When any target vault sets RSS `enabled` + `maxIn ≥ pull`:

```bash
PA_VAULT=<vault> PULL_USDC=700000000000 \
WITHDRAW_LOAN=... WITHDRAW_COLLATERAL=... WITHDRAW_ORACLE=... WITHDRAW_IRM=... WITHDRAW_LLTV=... \
forge script script/FirePositionSeed700k.s.sol:FirePositionSeed700k --rpc-url $BASE_RPC_URL --broadcast
```

Watcher: `script/watch_maxin_fire.py` (polls flowCaps; prints FIRE when maxIn > 0).

---

## Step 3 — Ops inventory (executed 2026-07-18)

| Wallet | Non-posted | Action |
|--|--|--|
| Loop `0x8d3c…8585` | **6.971123 USDC** | **Swept → KingVault** tx `0xc2dd5ab32bdc6a078333830216ef66139332c5395f244999e9fe706bdd414c8e` |
| Hot `0x6708…a7d1` | 1 RSS free, dust cbBTC (~8e-6), ~0.0016 ETH | Free RSS retained (dust); cbBTC dust below gas-economic sell; ETH = gas |
| Hot Morpho | ~18.5M RSS collateral | **DO NOT touch** — PoD collateral |
| KingVault | **6.971123 USDC** after sweep | Runway trough |

No LP positions / exotic inventory on Kingdom hot or loop. Further runway = curator maxIn or external deposits into yRSS.

---

## Step 4 — Flash discipline

See `FLASH-POLICY.md`. Flash only when repay source is a named on-chain step in the same atomic sequence. No flash to bridge a funding gap.
