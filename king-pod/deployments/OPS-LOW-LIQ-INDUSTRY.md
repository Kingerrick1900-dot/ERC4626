# How low-liq protocols pay ops (industry — not pocket, not $5 AMM)

King is not unique. Thin public DEX is normal. **Nobody funds payroll by dumping into their own $5 pool.**

## What real protocols actually do

| Method | Who | What it is |
|--|--|--|
| **OTC credit / warehouse loan** | Maple×Kraken, Ledn, Galaxy, desks | Borrow USDC/USD **against assets** — no DEX sale |
| **OTC treasury convert** | DAOs / foundations | Bilateral sale of tokens for stables at negotiated size — **off AMM** |
| **Standing liquidity line** | Institutional OTC | Pre-agreed RFQ: call desk → dollars against collateral / inventory |
| **Issuer surplus draw** | Sky/Maker-class | Ops paid from protocol surplus **in the stable** (fees/reserves) — only works once the stable clears to dollars via PSM/reserves |
| **TWAP / structured OTC** | Keyrock-class treasuries | Size out over time **with a desk**, not a public thin book |

Sources in practice: DAO treasury playbooks (stable runway + OTC, not spot dump); Maple/Kraken warehouse (borrow vs crypto, don’t sell); Sky pays ops from surplus USDS — because their dollar rail exists.

## What they do **not** do

- Seed a toy AMM with pocket dust and call it ops funding  
- Wait for “idle to appear” as the plan  
- Pretend minting a local stable = USDC payroll without a clear

## Kingdom map (same industry pattern)

You already did the **issuer mint** leg: eUSD against Elepan (real debt).

**Ops solution used by every low-liq book that needs dollars:**

1. **Open a credit line against the asset** (OTC / Ledn / Galaxy / Maple-style) → USDC to Landing → pay ops  
2. **Or OTC sell a slice of eUSD/Elepan** to a desk → USDC to Landing → pay ops  
3. eUSD payroll only if the vendor takes eUSD

That is the solution. Not Morpho “once.” Not self-pool. Not pocket.
