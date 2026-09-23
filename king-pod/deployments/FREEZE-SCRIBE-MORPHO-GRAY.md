# FREEZE — Scribe Morpho gray areas · audit + plan

**Mode:** FREEZE · ≤100-word plan  
**Control:** HOT = yRSS **owner + curator + allocator** · timelock **0** · withdrawQueue **9** (MetaMorpho **V1**) · `maxWithdraw` HOT = **0** (PARK 100% util; HOT = sole borrower)

---

## Audit (refine the Scribe)

| Claim | Kingdom fit |
|--|--|
| **1 forceDeallocate @ 0 fee** | **V2 tool.** King Vault V2 live penalty = **1%**, not zero. yRSS is **V1** — no `forceDeallocate`. Zero-penalty = King sets it on **V2** if wanted; still moves **own** adapter liquidity, does not mint Circle. |
| **2 Public Allocator JIT** | Real. Kingdom sets flow caps on **own** vault. **Foreign** Gauntlet/Steakhouse **maxIn=0** — PA cannot pull their USDC until they open caps. Own PA: reallocate yRSS markets you already enable. |
| **3 V1 withdraw queue** | **Applies.** yRSS V1 can walk the queue; still needs **idle in some queued market**. Today almost all claim sits in PARK @ 100% util. |
| **4 Bad debt socialize** | True Morpho law. Not an extract tool for payroll. |
| **5–6 Rate spike / partial withdraw** | Real pressure **on borrowers**. HOT **is** the PARK borrower — spiking util rates mostly taxes **yourself**. Useful only vs **external** borrowers. |

**Verdict:** Mechanisms move/access liquidity already in-system. None create USDC from eUSD. Power = control you already have (curator/allocator/V2 owner), aimed at **own** vault exit + **own** PA — not foreign vault fantasy.

---

## Plan (100 words)

Own the stack you already curate. On yRSS V1: `reallocate` any non-PARK idle to the front of the withdraw queue; keep Boss first for vacuum harvest. Do not rate-spike PARK against yourself. On King Vault V2: optionally set `forceDeallocatePenalty=0` for free adapter→idle exit, then withdraw Landing. Raise **own** PA maxIn/Out on kingdom markets only. Foreign PA stays blocked until curators open caps—packet, not code-mint. Parallel: PowerRail mint/ingest doors already shipped; harvest when any eUSD-coll book shows idle. Freeze until King names which lever fires first: V1 reallocate, V2 zero-penalty deallocate, or PowerRail.

---

## One-block

```
SCRIBE OK AS TOOLS · NOT USDC MINT
yRSS=V1 curator HOT · V2 forceDeallocate≠yRSS · penalty now 1%
PA=own caps only · foreign maxIn=0
rate spike≠self · plan=reallocate|V2-0feedealloc|PowerRail harvest
```
