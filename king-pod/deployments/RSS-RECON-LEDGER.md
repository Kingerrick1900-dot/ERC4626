# RSS RECON LEDGER — On-Chain Truth (Base)

**Status:** CRITICAL · HALTED · AWAITING FUNDING & RECOVERY  
**Date:** 2026-11-23 (America/Los_Angeles)  
**Doctrine:** Do not trust old “18.5M on hot” docs. This file supersedes them.

---

## Mission stand-down

`CrownRwaLoop` / Yearn leverage fire is **OFF**.

- No flash loops, no residual tricks, no Public Allocator equity hacks.
- Architecture is fine; **treasury seed is empty** (KingVault USDC = **$3**) and RSS was mis-located.
- Machine stays dark until: (1) RSS secured, (2) real USDC seed in vault, (3) ZK re-proven.

---

## Supply map (21,000,000,000 RSS)

| Location | Amount | Controllable? | Notes |
|--|--:|--|--|
| KingPair V1 `0x56ebfc0a…8f8c` | **20,981,500,000** | No | Stuck LP — no `releaseCollateral` |
| Morpho Blue (token bal) | **~11.36M** | Partial | Aggregate coll across RSS markets |
| **HOT Morpho coll (live)** | **9,497,295** | **YES — HOT** | Market `0x6075ba26…867b` (RSS coll / **eUSD** loan, 77% LLTV) |
| **HOT Morpho coll (peel)** | **100,000** | **YES — HOT** | Market `0x5dd0f7c1…27cf` (RSS coll / gUSD `0x319A…bc5d`, borrow 0) |
| Sale/stock contract `0xdbf7c4ad…065d` | **700,000** | **YES — owner HOT** | `buy` / `buyWithUsdc` / `stock` — sale inventory |
| HOT / Landing / Safe wallets | **0** | — | Docs claiming 18.5M on hot are **false** |
| Ghost residual vs old 18.5M figure | accounting / recycle | — | Not a ZK-bridge loss — see also `RSS-NOT-CRASH-LOCATED.md` |

**Recoverable kingdom RSS now:** ~**10,297,295** (9.497M + 100k Morpho + 0.7M sale).

---

## Trail (freed → re-locked)

Chunk/flash free put ~18.5M on HOT. Then HOT repeatedly called `postCollateral` helpers that **re-supplied Morpho**:

| Block | TX | Action |
|--|--|--|
| 48819820 | `0xaa0770d0…0d48` | Chunk free executed (freer `0xcFEa…823A`) |
| 48876768 | `0xcc5bc6c9…1345a` | HOT → `0x036e…A7B2` → Morpho RSS/USDC `0x40ac…b794` (~18.5M) + borrow |
| 49505277 | `0x36bf09b3…0df85` | HOT → `0xBAe8…2532` → Morpho RSS/USDC (~15.03M) + borrow |
| 50338510 | `0x76939ed6…dc57` | HOT → `0x151c…22eA` `postCollateral(0)` → Morpho **RSS/eUSD** `0xc61a…0599` (9.597M) |
| 50418791 | `0xe7452691…8450` | HOT `withdrawCollateral` from Morpho → HOT (9.597M) |
| **50418822** | **`0x29e59b95…831ae`** | HOT → `0x8960…f4ed` `postCollateral(0)` → Morpho **`0x6075ba26…867b`** (9.597M) |

**Live endpoint of the bag:** Morpho market `0x6075ba260df7fd5ad5bc9f1de33ac0bc2d8201dbe44b0081e89d9974f179867b`  
- loan: eUSD `0xE8aA…af8a`  
- coll: RSS  
- HOT coll: **9,497,295 RSS**  
- HOT debt: **~1,179,187,379 eUSD** (borrowShares against 100% util book)  
- Oracle: `0x264f7AfB…ba90` (elevated RSS price — Kingdom fixed-style)

**Peel book:** `0x5dd0f7c1…27cf` — **100,000 RSS** coll, **0** borrow (tx `0x2171b2f8…60f5`).

Not bridged to a ZK rollup in this trail — all Base Morpho. Prior write-up: `RSS-NOT-CRASH-LOCATED.md`.

---

## Liquid / ops board

| Item | Live |
|--|--|
| HOT USDC | 0 |
| Landing USDC | 0 |
| KingVault `0xA1aF…832a` USDC | **3** ($3) |
| HOT eUSD wallet | **3,000,000,000** (enough to repay ~1.18B debt) |
| HOT ETH | ~0.00014 |
| yRSS `totalAssets` | ~$401M class (matched Path B book) |
| HOT `maxWithdraw(yRSS)` | dust |
| ZK HOT / Safe | **unproven** (TTL stale) |

---

## Recovery plan (next operator — needs HOT key)

### A — Morpho 9.497M RSS
1. Re-prove ZK (HOT + Safe) before kingdom fire scripts; raw Morpho repay may be ops recovery.
2. `eUSD.approve(Morpho, debt)` — repay **~1.179B eUSD** from HOT wallet (has 3B).
3. `withdrawCollateral` full RSS → prefer **Landing** `0x5Adc…2357` (or Safe multi-sig).
4. **No recycle** into Morpho/yRSS until tested USDC exit (`NO-RECYCLE-UNTIL-EXIT.md`).

### B — 700k sale inventory `0xdbf7…065d`
- Owner = HOT. Selectors include `stock`, `buy`, `buyWithUsdc`, `pause`, `owner`.
- Inventory may be intended for USDC sale rail — audit ABI before sweep; possible USDC seed path if buyers hit `buyWithUsdc`.

### C — USDC seed (hard gate for Yearn loop)
- KingVault needs **real USDC** (>> $3).
- Sources: treasury transfer, or sell recovered RSS / sale-contract fills — **not** flash math.

### D — V1 20.98B
- Remains stranded. Do not repay ghost debt.

---

## Doc purge list (stale “18.5M on hot”)

Mark superseded → this ledger:

- `FLASH-FREE-RSS-LIVE.md` (post-state)
- `CHUNK-FREE-LIVE.md` (post-state)
- `BOOKS-CLEARED-MORPHO.md` (hot RSS line)
- `VAULT-V2-LIVE.md` (wallet RSS line)
- `RSS-LOCATION-AND-FREE.md` (Morpho freeable line)
- `WHALE-SCALE-PLAN.md` (inventory line)
- `LIVE-FIRE-PACKAGE.md` — stand-down banner

---

## Bottom line

Ledger was wrong; architecture wasn’t.  
**~9.50M RSS is on Morpho under HOT** (eUSD-debted). **0.70M RSS** sits in HOT-owned sale contract.  
**HOT wallet RSS = 0.** Yearn loop stays **OFF** until repay/withdraw + USDC seed + ZK.
