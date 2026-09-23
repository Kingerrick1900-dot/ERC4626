# CIRCLE ENGINE — eight numbers (FORK PROVEN · NO FIRE)

**Mode:** proof only · no broadcast  
**Method:** `forge test --match-test test_eightNumbers_exactFork -vv --fork-url $BASE_RPC_URL`  
**Fork block:** `51700287` (Base) · PASS  
**Gas meter:** `gasleft()` around `unwindKnot()` only (excludes deploy/auth)

---

## Exact figures (raw + USDC 6dp)

| # | Field | Raw | USDC / units |
|--|--|--|--|
| **1** | **Flash amount** | `219392728896391` | **$219,392,728.896391** |
| **2** | **Flash fee** | `0` | **$0** (Morpho Blue flash fee = 0) |
| **3** | **Repay amount** | `219392728896390` | **$219,392,728.896390** (full borrow shares, toAssetsUp) |
| **4** | **Supply withdrawal** | `218301349241287` | **$218,301,349.241287** |
| **5** | **yRSS peel output** | `1082115689816` | **$1,082,115.689816** |
| **6** | **RSS freed** | `252000000000000000000000` | **252,000 RSS** (18dp wei) |
| **7** | **Final dust → Landing** | `99999998` | **$99.999998** |
| **8** | **Gas used** | `1145571` | **1,145,571 gas** |

---

## Required prefund (not theater — math)

After IRM accrue at 100% util, **debt > supply + yRSS** by the interest gap:

| Field | Raw | USDC |
|--|--|--|
| Accrued shortfall (at size) | ≈ `9263965285 − 100e6` | **~$9,263.97** |
| Prefund on engine in proof | `9363965285` | **$9,363.965285** (= shortfall + $100 cushion) |

Without prefund, callback reverts `Short()`. Prefund is **exact cover**, not a “wire $700k” lecture.

Conservation check (proven):

```
supplyWithdrawal + yRSS_peel + prefund − dust = repayAmount
218301349241287 + 1082115689816 + 9363965285 − 99999998 = 219392728896390
```

Flash = repay + 1 wei.

---

## Drift warning

At 100% util, AdaptiveCurve IRM grows debt every block. **Re-run the fork test immediately before any fire** and replace these eight numbers. Do not fire on stale figures.

```bash
cd king-pod
forge test --match-test test_eightNumbers_exactFork -vv --fork-url $BASE_RPC_URL
```

---

## Still no fire

King has the eight numbers. Freeze holds until King orders fire with a fresh proof tip.
