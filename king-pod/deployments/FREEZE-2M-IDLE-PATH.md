# FREEZE — $2M unlatched idle engineering path

**Mode:** FREEZE · info only · no broadcast  
**Ask:** lasting **$2,000,000** unmatched Morpho USDC idle (park `0x41c08085…`)  
**Live now:** idle **$1.514572** via `CrownUnlatchIdle` `0xEC84…FFC4` (PSM dust proof)

---

## Law (non-negotiable)

```
lasting_idle = supply − borrow   (unmatched USDC only)
```

| Move | Lasting idle |
|--|--|
| Supply USDC, do not borrow | **+USDC** |
| Repay borrow, do not withdraw supply | **+USDC** |
| Flash → supply → borrow same book (gasPark) | **$0** |
| Flash → repay → withdraw supply/shares to repay flash | **$0** (temp idle only) |

**Identity:** any path that closes a flash by borrowing the idle you just made re-latches.  
**Identity:** lasting idle size ≤ **external USDC equity** (king rail or foreign depositor) in every closed system.

---

## Live blockers (read 2026-09-09)

| Fact | Number |
|--|--|
| Park idle | ~$1.51 |
| Excess king borrow vs HOT supply (vault latch) | ~**$1.01M** |
| yRSS claim / maxWithdraw | ~$1.01M claim · maxW ≈ idle |
| HOT USDC | **$0** |
| HOT kingdom eUSD | ~6.45M (keep — doctrine) |
| Borrow headroom on park (RSS coll) | ~**$29M** but **no liquidity to borrow** |
| cbBTC/USDC Morpho idle | ~**$195M** — wrong collateral (need cbBTC) |
| WETH/USDC Morpho idle | ~**$10.8M** — need WETH |
| keUSD/USDC Morpho (`0x5d46483a…`) | liquidity **~$0.80** |
| Foreign PA maxIn → park/rss40 | **0** |
| Park `reallocatableLiquidityAssets` | **0** |
| `publicAllocatorSharedLiquidity` → park | **[]** |

---

## False loopholes (do not fire)

1. **gasPark / self-borrow** — flash supply + borrow park to repay flash → util 100%, idle $0. Already how the $1M yRSS latch was born. `CrownUnlatchIdle` hard-reverts `borrow`/`gasPark`.
2. **Flash + 90% util partial borrow** — lasting idle equals **equity**, not flash size. Flash $2M + borrow $2M ⇒ idle $0; flash $2M + equity $2M + borrow $0 ⇒ idle $2M (you still spent $2M).
3. **Buy cbBTC with flash → borrow USDC → fill park** — LLTV haircut needs **≥~$0.3M+ equity** for $2M out; kingdom has $0 USDC. Also sells into a loop, not a free mint.
4. **forceDeallocate** — exit access at 100% util; **does not create outside TVL / lasting idle**.
5. **Swap kingdom eUSD → USDC** — Uni pools are dust; doctrine **keep eUSD**.

---

## Real paths to $2M lasting idle (ranked)

### P0 — King USDC rail (engineering already live)

1. Land **$2M Circle USDC** on HOT (OTC / wire / treasury).  
2. `CrownUnlatchIdle.engineerIdle(2_000_000e6)` @ `0xEC84…FFC4`.  
3. `minIdleBuffer` auto-locks so peel cannot re-latch.  
4. Robots may `peelSurplus` only after owner lowers buffer.

**Result:** park idle += $2M. yRSS maxWithdraw opens up to ~$1.01M claim; residual idle stays as engineered buffer.

### P1 — Soft loophole: foreign PA (no king USDC)

Whale-scale sheet Play A2:

1. Curator packet: Gauntlet USDC Prime + Steakhouse Prime set **PA maxIn ≥ $2M** on park and/or classic RSS `0x40ac09f3…`.  
2. When `reallocatableLiquidityAssets ≥ $2M` / shared liquidity non-empty → PA `reallocate` into target market.  
3. That is **foreign depositor USDC** becoming unmatched supply on our book = lasting idle.

**Block today:** maxIn=0, reallocatable=0. Not a code bug — **permission gate**.

### P2 — Repay wedge (same equity identity)

`unlatchRepay(2_000_000e6)` cuts king park debt → idle +$2M. Still needs **$2M USDC**. Same cash cost as P0; prefers deleverage over adding supply.

### P3 — Different deliverable (not lasting $2M idle)

Atomic flash unlatch to **Landing payroll** from shares:

- Flash → repay → `yRSS.withdraw` ~$1.01M → Landing → withdraw HOT supply to repay flash.  
- Nets ~**$1M Landing**, **$0 lasting idle**.  
- Caps at vault claim (~$1.01M), **cannot** mint $2M idle or $2M Landing.

Use only if King renames the ask from “$2M idle” to “unlock shares to Landing.”

---

## Recommended freeze decision

| If King means… | Do this |
|--|--|
| **$2M lasting Morpho idle** | **P0** rail $2M → `engineerIdle`. Only atomic path under kingdom keys today. Parallel **P1** packet to foreign curators. |
| **~$1M spendable on Landing** | Rename ask → P3 flash-liberate (or P0 $1M then peel with buffer lowered). |
| **$2M without USDC in** | **Impossible** under Morpho accounting while foreign maxIn=0. Refuse any script that claims otherwise. |

---

## Seat line

EV of another gasPark demo: **negative** (re-latches).  
EV of P0 when $2M USDC arrives: **idle +$2M**, shares unlock ≤ claim.  
EV of P1: **idle +$2M** if curators open maxIn — zero king USDC, dependency external.

**No broadcast until King names P0 / P1 / P3 and funds or packets accordingly.**
