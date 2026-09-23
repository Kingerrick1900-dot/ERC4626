# FREEZE AUDIT — Depth-First + P1.5 HOT→Circle

**Depth-First (P2):** Correct for optics/moat. Keep ocean ~5B. Does not open park util.

**P1.5 as written ($2.45M eUSD → borrow $1.01M USDC on Boss):** **False.**
Boss market live idle ≈ **$0.80** (supply ~$1.80 − borrow ~$1.00). Coll sets borrow *capacity*; loan USDC must already sit on the book. Borrowing $1.01M **reverts**.

**What we engineer instead (no waiting on a vendor):**
1. **Drain Boss** — post HOT eUSD, borrow **all** Boss USDC idle, repay-for park, peel yRSS → Landing (`CrownBossWedge`).
2. **Vacuum** — same call whenever Boss idle refills (curator queue already sends new yRSS USDC to Boss first).
3. **Depth** — ocean keeps attracting fill onto that loan side so the vacuum scales.

Not legal theater: no index inflate, no wash, no ZK-write.
