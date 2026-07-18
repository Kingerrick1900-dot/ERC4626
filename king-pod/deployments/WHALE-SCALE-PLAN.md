# WHALE SCALE PLAN — King Errick (Base)

**Inventory now:** ~**18.5M RSS** free on hot · Morpho RSS market empty · foreign PA **maxIn=0** · ops USDC ~$1  
**Math unlocked:** 18.5M RSS × $1 oracle × **77% LLTV** = **~$14.2M** max borrow **if** USDC supply exists in the market.

The bottleneck is not “find a dust yield.” It is **foreign USDC depth into `RSS_MARKET`**. Gauntlet/Steakhouse vaults hold **hundreds of millions** USDC on Base with **zero** flow caps into King’s market. That door is the whale.

---

## PLAY A — Curator door → $1M–$14M borrow (PRIMARY)

**Goal:** Turn free RSS back into a **borrow machine** against live vault liquidity.

| Step | Action | Owner |
|--|--|--|
| A1 | Re-post **18.5M RSS** as Morpho collateral only (no self-supply loop) | Chief / hot |
| A2 | Blast curator packet: set PA `flowCaps` **maxIn ≥ $700k–$5M** on RSS market for Gauntlet USDC Prime `0xeE8F…b61` + Steakhouse Prime `0xBEEF…b2` | King + packet |
| A3 | On first non-zero maxIn: `CrownSpoilFire.fire` / PA `reallocateTo` → borrow to **KingVault** | Chief |
| A4 | Scale asks: $700k → $2M → $5M → headroom cap (~$14.2M) as caps rise | King |

**Why this is whale:** same collateral, external USDC, real cash to KingVault.  
**Block today:** maxIn=0. Without A2, borrow is impossible (idle ≈ $1).

**Do NOT:** rebuild the self-lend mirror (supply USDC + borrow same USDC). That was a science loop, not payroll.

---

## PLAY B — RSS monetization rail (PARALLEL)

**Goal:** Turn RSS inventory into USDC without waiting on curators.

| Step | Action |
|--|--|
| B1 | Name buyer / MM / OTC desk for RSS (size: 1M / 5M / 18.5M tranches) |
| B2 | Wire `KingRssSale` (or escrow) — USDC in, RSS out, KingVault receive |
| B3 | Seed Aerodrome RSS/USDC only **after** real USDC war-chest exists (not with $1) |
| B4 | Proceeds: either seed Morpho RSS market (unlock Play A without curator) **or** treasury ops |

**Why whale:** cash exit on 18.5M units. Oracle $1 ≠ bid — price is negotiated.

---

## PLAY C — Self-seed bootstrap (IF King brings USDC)

**Goal:** Skip foreign curators by supplying USDC into RSS market yourself.

| Step | Action |
|--|--|
| C1 | Park external USDC into Morpho RSS market (supply) |
| C2 | Borrow against posted RSS to KingVault up to LLTV−buffer |
| C3 | Net extract ≈ borrow − keep supply locked as depth (or rotate) |

**Requires:** outside USDC. Ops dust cannot open this.

---

## KILL RULES (so scale doesn’t die again)

1. **No dust carry / no cbETH toys** under $50k notional.  
2. **No self-loop mirror** as “funding.”  
3. **No flash that frees collateral** unless King says `FREE_RSS=1`.  
4. **Only fire borrow** when `market.idle ≥ ask` OR PA maxIn ≥ ask.  
5. Every scale tx names: size, ask USDC, repay/borrow source, HF after.

---

## IMMEDIATE SEQUENCE (next 3 moves)

1. **King:** pick Play A (curator pressure) and/or Play B (buyer name).  
2. **Chief:** on order only — re-collateralize 18.5M RSS (Play A1), arm SpoilFire for first PA fill.  
3. **Chief:** do not touch RSS inventory for “experiments.”

**Scoreboard that matters:** KingVault USDC ↑ · RSS coll posted · foreign maxIn ↑ · HF ≥ 1.3  
Not: script count, dust APY, or freed tokens with no bid.
