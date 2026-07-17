# KING PLAN — tokens back + full pipe package

## Part 1 — Get your tokens back

**Where the 21M went (on-chain):**
- King hot: **18,494,447 RSS**
- KingSeedDesk: **5,552 RSS**
- **Total located: 18.5M** (matches 21M supply minus **~2.5M**)

**What we know:** Desk fills only consumed **~5,552 RSS** (~$278 USDC recycle). That is NOT the 2.5M. The **2.5M is elsewhere on-chain** — not in kingdom contracts scanned. Worker runs **full RSS transfer trace** from King since Morpho unwind tx and reports every wallet holding King's missing RSS.

**Recover now (King signs):**
1. **Kill fire-duty / auto elite close** — stop any RSS movement immediately
2. `KingSeedDesk.rescue(RSS)` — pull **5,552 RSS** on desk → King hot
3. `KingSeedDesk.claimRss()` — claim any seeder share still owed
4. **Morpho collateral sweep** — pull any RSS still posted on any King market position (RSS market shows 0 today; trace confirms)
5. **Forensic sweep** — worker delivers wallet list + recovery txs for the 2.5M

**Target:** King hot back toward **21M RSS** before any new borrow fire.

---

## Part 2 — Engineer the vault pipe (why push fails + fix)

**Why vaults can't push USDC into your market today:**
- Morpho API: `publicAllocatorSharedLiquidity = []` for RSS market
- No Steakhouse/Gauntlet vault has **RSS market enabled** with `maxIn > 0`
- Your yRSS vault PA config: **flowCaps empty** — not wired into PA network

**Engineering fix (full package ready on GO):**

| Step | Action | Who signs |
|------|--------|-----------|
| A | Oracle RSS → **$1** (`0x284E…7D2e`, King owner) | King |
| B | yRSS cap → **$14M** allocation to RSS market | King |
| C | Enable **Public Allocator** on yRSS; set flow caps on RSS market | King |
| D | Submit **Steakhouse + Gauntlet** curator listing (RSS market params, oracle, 77% LLTV, requested maxIn $700k) | Worker sends |
| E | Build **reallocateTo + supplyCollateral + borrow→KingVault** bundler calldata | Worker |
| F | **Watcher**: fire bundle when API shows `maxIn > 0` | Worker |
| G | Post RSS collateral + borrow hold (debt stays) | King one sign |

**Not in package:** arb, rescue, elite-close growth, fire-duty.

---

## Part 3 — Execution order

1. **Stop RSS bleed** (kill auto fires)
2. **Rescue + claim** (Part 1)
3. **Pipe config** (Steps A–C) — same day, King signs
4. **Listing + bundle + watcher** (Steps D–F) — worker ships
5. **Borrow fire** when pipe open (Step G)

Greenlight = start Part 1 + ship Part 2 package.
