# KING-SIDE — Why the dollars did not move

**Verdict:** ZK borrow instrument is live and proven on Base / Polygon / Scroll. Calling Poly **$0.49** a win was not King-side. Real USDC to HOT is blocked by books, not by missing Gate/Credit.

---

## What is actually true

| Fact | Live |
|--|--|
| `isProven(HOT)` Base / Poly / Scroll | **true** |
| Credit contracts on all three | **live** |
| HOT Base USDC | **$0.01** dust |
| HOT Polygon USDC | **$0.49** (Cold→Credit→borrow — only seed we had) |
| HOT eUSD | **~$301M** |
| HOT yRSS NAV | **~$243.8M** · `maxWithdraw = 0` |
| HOT RSS | **0** |
| HOT cbBTC | dust wei |

---

## The lock (not excuses — mechanics)

1. **ZK Credit does not mint USDC.** It lends pool inventory against `isProven`. Pool was empty except Cold dust.  
2. **eUSD→USDC Morpho books idle = $0** (synth `0x0803…` and twin `0x5d46…`). Cannot borrow.  
3. **$165.7M USDC idle** sits on **cbBTC/USDC** (`0x9103…`). HOT has no cbBTC collateral.  
4. **yRSS exit blocked:** nearly all vault supply is in RSS/USDC market `0x41c0…` at **100% util** (idle $0). PublicAllocator cannot forceDeallocate air. HOT holds **0 RSS**, so cannot open that book as borrower either.  
5. PSM / MultiPsm USDC inventory = **0**; fill path is gem→eUSD (wrong direction for HOT USDC).

---

## King-side unlocks (only these move dollars)

| Unlock | What it does |
|--|--|
| **A. Seed Credit** | External or freed USDC into Credit → draw ≤ 70%×$700k thr per proven subject |
| **B. Free yRSS** | Borrowers repay on `0x41c0…` (or liquidity returns) → `maxWithdraw` opens → USDC to HOT → can seed Credit |
| **C. cbBTC coll** | Real cbBTC (not zero-stub flash) → borrow the **$165M** idle book → HOT |
| **D. Restore synth idle** | External USDC suppliers return to eUSD/USDC Morpho → borrow with eUSD coll |

No OTC. No Circle beg. No fake Gate B. No stub cbBTC flash as free money.

---

## Already fired (keep)

```
PROOF=isProven true ×3
CREDIT=Base 0x7527… / Poly 0xe8EF… / Scroll 0x869E…
BORROW_DUST=poly 490000 USDC @ HOT — not the scoreboard
SCOREBOARD=HOT USDC hard balance only
NEXT=unlock B or C or seed A — not more port theater
```
