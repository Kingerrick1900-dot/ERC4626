# FREEZE — CN Builds (refined before fire)

**Mode:** FREEZE → then FIRE · Cursor-ready scaffolds  
**Doctrine:** Loan ≠ sell RSS. **No Lakala / CIPS / CN-chain patent forks.** Crown-original class surfaces only.

---

## Plan fixes (what didn’t work → better)

| Original ask | Why it breaks | Refined deliverable |
|--|--|--|
| Fork “Chinese stablecoin chain” as `CrownParallel.sol` | A Solidity file is not an L1 fork; can’t ship CN chain bytecode | **`CrownParallelSettlement`** — multi-rail settlement ledger (Base/Poly/Scroll ids) for CN desk clears |
| `RoyalCardNFC` = Lakala offline-cache **patent** fork | Patent copy forbidden | **`CrownRoyalCardNFC`** — offline receipt **cache class**: signed tap → later settle (Crown-original) |
| `CrownCIPS` = real CIPS bridge | No banking license / SWIFT-CIPS socket on-chain | **`CrownCIPSCorridor`** — Open Money path: invoice → eUSD → **USDC settle** (corridor semantics) |
| Stealth = private mempool on parallel chain | Base has no owned private mempool; no Hunt on “CN L1” | **`CrownStealthRouter`** — HuntRouter + ZK borders + intent commit hash; bots on **Base** (Morpho flash) |

---

## Deliverables (Cursor-ready)

1. `src/china/CrownParallelSettlement.sol` + KAR wire notes  
2. `src/china/CrownRoyalCardNFC.sol` → PayAdapter / RoyalCard  
3. `src/china/CrownCIPSCorridor.sol` → OpenMoney + USDC out  
4. `src/china/CrownStealthRouter.sol` → HuntRouter · 3 bots · sweep HOT  

Tests: Base fork. Deploy: Polygon commerce + Base hunt (gas permitting).

---

## One-block

```
FREEZE=cn-builds-refined
NO=patent-fork · fake-L1 · fake-CIPS-socket
YES=parallel-settle · NFC-offline-cache-class · CIPS-corridor-USDC · stealth-hunt-ZK
FIRE=scaffolds+wire+fork-test+deploy
```
