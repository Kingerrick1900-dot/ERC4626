# Path B — Gap STRUCK · fork PASS

**Law:** Path A **REMOVED**. **$4.4M yRSS gap STRUCK** — deleted from the path. Not capital. Not a blocker.

---

## Debt origin

HOT Morpho borrow vs **252k RSS**, funded by **yRSS suppliers** — not King wallet USDC.

---

## Path (clean)

Flash → repay bulk → pull King yRSS → **reserve flash** → cut surplus into debt → free max RSS to sovereign `0x1293…` → repay flash.

---

## Fork `test_path_b_gap_struck_max_free` — PASS

| Result | Value |
|--|--:|
| RSS on sovereign | **222,524** (~88.3%) |
| RSS residual legacy | **~29,476** (healthy LLTV) |
| Residual debt | ~**$27.1M** (< max ~$27.2M) |
| King USDC inject | **0** |
| Oracle | **$50,000** live |

The struck gap is not used. Migration does not wait on minority shares.

---

```
PATH_A=REMOVED
GAP_4_4M=STRUCK
PATH_B=PASS
SOVEREIGN_RSS~=222524
BLOCKER=NONE
```
