# RSS located — not a server crash

**Verdict:** Liquid RSS was never lost to the Sep 30 crash. It is Morpho Blue collateral under HOT, posted intentionally in Aug 2026.

## Live inventory (Base, read 2026-10-01)

| Amount | Where | Notes |
|--------|--------|------|
| **~9,497,295 RSS** | Morpho collateral on HOT · market `0x6075ba260df7fd5ad5bc9f1de33ac0bc2d8201dbe44b0081e89d9974f179867b` | Loan = eUSD `0xE8aAD0DD…Caf8a` · oracle `0x264f7AfB…` · LLTV 77%. HOT is sole borrower on this book. |
| **100,000 RSS** | Morpho collateral on HOT · market `0x5dd0f7c171f7de8899ca1025bfd9ee2fe2153762c532b691b1bdb344f46227cf` | Loan = `0x319A49BB…bc5d` · same oracle family. Peeled from the 9.597M bag. |
| **0 RSS** | HOT wallet `0x6708…a7d1` | Expected while Morpho books are open. |
| **~20,981,500,000 RSS** | KingPair V1 `0x56ebfc0a…8f8c` | Still stuck in V1 LP (unchanged; not crash-related). |

Helpers / Landing hold **0** RSS wallet balance. Morpho contract RSS balance (~11.3M) includes Kingdom collateral + other market users.

## Trail (not crash)

1. **2026-08-23** · block `50338510` · tx [`0x76939ed6…dc57`](https://basescan.org/tx/0x76939ed6763e0b549903d50f9c21239672b9b805be4f87c841523176acc3dc57)  
   HOT → helper `0x151C947B…22eA` (`postCollateral`) → Morpho market `0xc61adc05…0599` (eUSD/RSS) · **~9,597,295 RSS** onBehalf HOT. Owner of helper = Landing `0x5Adcea53…2357`.

2. **2026-08-25** · block `50418791` · tx [`0xe7452691…8450`](https://basescan.org/tx/0xe74526910e1ade7dc23a004de886d8e462f700931d44ff281d1a006096818450)  
   HOT `withdrawCollateral` from `0xc61adc05…` → HOT wallet (full ~9.597M).

3. **2026-08-25** · block `50418822` · tx [`0x29e59b95…31ae`](https://basescan.org/tx/0x29e59b9581da18b3dbe8eb7cd9f8810045c00463dae23d079804bd989a4831ae)  
   HOT → helper2 `0x8960bdbe…f4ed` → Morpho market **`0x6075ba26…867b`** · **~9,597,295 RSS** onBehalf HOT. Helper2 owner = Landing.

4. **2026-08-25** · block `50425718` · tx [`0x2171b2f8…60f5`](https://basescan.org/tx/0x2171b2f848d910a8bdbf32ab49e0c62e7bf61abd8d36287c5895b08dd4be60f5)  
   Peel **100,000 RSS** off `0x6075ba26…` → HOT → helper `0x380e1990…767d` → Morpho market **`0x5dd0f7c1…27cf`**. Leaves **~9,497,295** on the main book.

Pre-dump HOT wallet balance at block `50338509` was already **~9.597M** (not the older 18.5M save-sheet figure). Nothing in this path touches Sep 30 infra.

## How to free (ops, not this agent)

Repay eUSD debt on market `0x6075ba26…` (HOT sole borrow), then `withdrawCollateral` → HOT. Same pattern for the 100k book `0x5dd0f7c1…`. Do **not** recycle into Morpho until a tested USDC exit exists (`NO-RECYCLE-UNTIL-EXIT.md`).
