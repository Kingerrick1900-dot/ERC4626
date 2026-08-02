# Cross-market credit plan — $500k Landing (no buyers)

**Doctrine:** ELE is **kingdom asset**. Post as Morpho collateral. Never sell for ops.  
**Goal:** Base Landing ≥ **$500,000 USDC**  
**Pattern:** Morpho Public Allocator — route foreign idle into ELE77, borrow against posted ELE.  
**Builds:** none. Live extractor + PA only.

---

## Why this (elite, not feeble)

Peers clear dry native books by tapping **deeper markets**, not by finding token buyers. Morpho PA is that mechanic: USDC idle in WETH/cbBTC vault allocations → `reallocateTo(ELE77)` → borrow against coll already posted.

## Live position

| Piece | Status |
|--|--|
| ELE coll on ELE77 | ~**2,000,003 ELE** (kingdom asset) |
| Borrow headroom @ 77% | ~**$840k** (≥ $500k) |
| ELE77 idle | ~**$0** (matched) |
| Morpho WETH/USDC idle | ~**$7.9M** |
| Morpho cbBTC/USDC idle | ~**$145M** |
| Steakhouse / Gauntlet ELE77 | **disabled · maxIn=0** ← block |
| Extractor | `0x5d99EEf1954053EDc4D73ba1429E51DaC539bf58` · `borrowIdle` live |
| Curator packet | `CURATOR-PACKET-ELE77.md` |

## Steps

1. **Curator door** — Steakhouse Prime / Gauntlet USDC Prime (and peers): enable ELE77 + PA **maxIn ≥ $500k** (prefer $700k); keep WETH/cbBTC **maxOut** ≥ ask.  
2. **PA pull** — when maxIn live: `reallocateTo` ≥ $500k from WETH/cbBTC → ELE77 (existing PA / extractor path).  
3. **Borrow** — King `borrowIdle(500000000000)` → Landing.  
4. **Preflight** — ELE77 idle ≥ ask; headroom ≥ ask; no self-seed; no new contracts.

## Kill

- Token buyers / OTC as the plan  
- Flash-supply-borrow remainder-0  
- Selling ELE  
- Live fire while idle < ask  

## Scoreboard

Landing USDC ≥ **$500,000**. ELE remains kingdom collateral.
