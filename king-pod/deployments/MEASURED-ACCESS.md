# Measured Access — Spec (C) + Fire A/B

**Doctrine:** USDC from lenders, not thin air. Vault deposit proper. Borrow idle. Exit to HOT.  
**Contract:** `CrownMeasuredAccess` · event `AccessCompleted`

---

## Parts

| Part | Action |
|--|--|
| **A** | Post eUSD collateral on Morpho eUSD/USDC → borrow **market idle** USDC → HOT |
| **B** | HOT USDC → `ySYNTH.deposit` (vault-routed) · cbBTC/WETH borrow needs those assets as coll |
| **C** | This spec · `minRetain` gate · no flash ghost loop |

---

## Constraints (honest)

- ySYNTH `asset` = **USDC** — cannot `deposit` eUSD into ySYNTH.
- After ghost unwind, synth market idle is **dust** until external lenders return.
- cbBTC/WETH books have deep idle, but HOT holds **~257 wei cbBTC / 0 WETH** — no meaningful borrow.
- Offshore CN structure (image point 5) is **ops/legal**, not an on-chain loophole module.

---

## Scale path

1. External USDC deposits → ySYNTH (or Morpho supply) restore idle.  
2. Keep eUSD posted as coll · borrow rising idle to HOT.  
3. Or acquire cbBTC/WETH · borrow those books' idle.  
4. Raise size only after `AccessCompleted.borrowedToHot` is real and retained.

```
ACCESS=CrownMeasuredAccess
A=eUSD→borrow synth idle→HOT
B=USDC→ySYNTH.deposit
C=this-spec
```
