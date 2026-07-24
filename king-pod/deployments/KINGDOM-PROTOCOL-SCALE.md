# Kingdom Protocol Scale — SYSTEM PLAN (no live fire)

**Status:** PLAN ONLY · **Nothing broadcasts without King GO + phase flag**  
**Doctrine:** Use the Kingdom stack we already own. Merkl whitelist is **optional amp**, not the critical path. No more deadlocks on “waiting.”

---

## 0) What we already are (live rails)

This is not a bag looking for a tip. This is a protocol skeleton on Base:

```
Elepan (coll / soft $1)
    │
    ├─► Sovereign CDP 0x46b1…1174
    │       ACCESS CLAUSE: mint eUSD → Landing only
    │       selfLiquidate armed · HF ~1.94 · 25.2M coll / ~13M debt
    │
    ├─► Multi-minter eUSD 0xE8aA…af8a  (Landing holds ~13M)
    │
    ├─► Morpho Elepan/USDC 0xa4ec…53fc  (LLTV 77%, soft $1 oracle)
    │       idle today ≈ $2  ← empty book, not broken rail
    │
    └─► yELEPAN-USDC 0x61bf…145E  (King owner/curator)
            cap $14M · PA maxIn/Out $700k · fee 10% → Landing
```

Hot = ops · Landing = cold treasury · King curates the USDC magnet.

**Scoreboard that matters:** Landing USDC ↑ · vault TVL ↑ · eUSD convertibility ↑ · HF ≥ target  
Not: Merkl form status · script count · matched flash optics.

---

## 1) What “wait on Merkl” got wrong

| Mistake | Why it deadlocks the King |
|--|--|
| Merkl as gate to payroll | Merkl is **marketing emissions**. Registry is offchain. King cannot force it. |
| “Find USDC LPs then borrow” as the only plan | Puts protocol life on strangers + Angle ops calendar. |
| Treating empty idle as failure of the system | Idle=$2 means **book not filled**. Rails (vault, market, PA, CDP) are already live. |

Merkl pack stays **armed and parallel** (`MERKL-YELEPAN-CAMPAIGN-GO.md`). It is **not** Stage 0.

---

## 2) Protocol flywheel (how the system scales)

```
                 ┌─────────────────────────────────────┐
                 │         KINGDOM PROTOCOL            │
                 └─────────────────────────────────────┘
                                    │
     ┌──────────────────────────────┼──────────────────────────────┐
     ▼                              ▼                              ▼
  ISSUANCE                     CREDIT MARKET                    CONVERT
  Elepan → CDP                 yELEPAN-USDC (King curates)      eUSD ↔ USDC
  eUSD → Landing               Morpho Elepan/USDC borrow         PSM / Redeemer
  (ACCESS CLAUSE)              USDC → Landing on borrow          (MISSING — build)
     │                              │                              │
     └──────── fees / repay / HF discipline ───────────────────────┘
                         Landing = protocol treasury
```

Three jobs, three rails:

1. **Issue** — already live (cold mint, self-liq safety).  
2. **Credit** — already live (own curator vault + moat market). Needs **USDC in the book**.  
3. **Convert** — **not built**. Without eUSD↔USDC, Landing’s 13M eUSD is not spendable payroll.

Scale = run all three. Not wait for Merkl.

---

## 3) Stages (King names GO per stage)

### Stage P0 — Convertibility (protocol missing piece)
**Build, no fire until GO `FIRE_PSM=1`.**

| Deliverable | Purpose |
|--|--|
| `CrownEusdPsm` (or Redeemer) | Swap eUSD ↔ USDC at soft peg with fee → Landing |
| Reserve policy | USDC reserve on Landing / PSM; King sets mint/redeem caps |
| Kill | Pause, fee floor, daily redeem cap |

**Why this is “using the system”:** CDP already issues eUSD to Landing. PSM makes that issuance **money** in the real world. Merkl cannot do this.

**Bootstrap reserve (King chooses one before fire):**
- Wire external USDC into PSM/Landing, **or**
- OTC sell a slice of Elepan/eUSD into USDC reserve (named buyer), **or**
- After P1 borrow, park first USDC tranche as PSM reserve (no recycle theater)

### Stage P1 — Own-curator credit fill (King operates his vault)
**No Merkl. No foreign curator beg. GO: `FIRE_VAULT_SEED=1` then `FIRE_BORROW=1`.**

This is Play C from whale doctrine, on **Elepan** rails:

1. King (or named capital) supplies USDC into **yELEPAN-USDC** (King already owns curator).  
2. Allocator/PA parks into Elepan/USDC market.  
3. Hot posts free Elepan as Morpho coll.  
4. `FireElepanBorrowUsdc` — USDC to **Landing**, gated by `IDLE_FLOOR`.  
5. First Landing USDC → either ops **or** PSM reserve (King picks).

**Net:** capital runs through **Kingdom-owned** vault + market + access-clause treasury. Fees 10% → Landing. That is protocol operation, not tip-seeking.

| Guard | Rule |
|--|--|
| Idle floor | No hope-borrow under King floor (default $100k unless overridden) |
| First tranche | ≤ 50% of idle unless King overrides |
| HF | Morpho + CDP HF posted before fire |
| No self-mirror theater | Do not call supply+borrow of same USDC “yield” |

### Stage P2 — Safety + issuance discipline (already mostly live)
- Keep CDP HF ≥ King floor (~1.5+); self-liq remains the escape.  
- Mint only to Landing (ACCESS CLAUSE).  
- Optional: more Elepan into CDP only when convert (P0) or credit (P1) can absorb eUSD.  
- ZK gate / proven hot stays on.

### Stage P3 — External magnet (optional amp)
Only after P0 or P1 has a non-zero USDC story:
- Merkl Elepan emissions on yELEPAN-USDC (**if/when whitelist clears**)  
- Curator door packets to foreign MetaMorpho (Gauntlet/Steakhouse maxIn)  
- DEX Elepan/USDC **after** war-chest exists (not with $3 dust)

These grow the book. They do not define the protocol.

---

## 4) What King decides (no engineering fire until named)

| Decision | Options | Blocks |
|--|--|--|
| **D1 Convert path** | Build PSM now / OTC reserve first / defer convert | P0 |
| **D2 Credit seed size** | King USDC into yELEPAN: $X | P1 |
| **D3 First borrow ask** | $ ask + `IDLE_FLOOR` | P1 borrow |
| **D4 Merkl** | Keep parallel / pause / cancel | never blocks P0–P2 |
| **D5 Phase flags** | Exact `FIRE_*=1` names | every broadcast |

Chief will not broadcast on silence. Silence ≠ GO.

---

## 5) Kill rules (so we don’t deadlock again)

1. **No live tx without King GO + phase flag.**  
2. **No plan whose critical path is an offchain third-party form.**  
3. **No flash-seed USDC left in pool** (same-tx repay law).  
4. **No “payroll” claim from matched books or eUSD sitting idle.**  
5. **Merkl failure never stops P0/P1.**  
6. Every fire names: size, rail, Landing delta, HF after.

---

## 6) Immediate engineering (docs/code only — this branch)

Until King GO:

1. Spec + stub `CrownEusdPsm` (P0) — interfaces, fee, pause, reserve accounting.  
2. Restore `CheckYelepanUsdcReady` + `FireElepanBorrowUsdc` onto this line (P1).  
3. Demote Merkl docs to **optional parallel**.  
4. One scoreboard script: Landing USDC, yELEPAN TVL, Morpho idle, CDP HF, eUSD supply.

**Armed Merkl encode stays ready** if whitelist ever clears — fire only on `FIRE_MERKL=1`.

---

## 7) One-line doctrine

> Kingdom scales by **issuing into Landing, curating its own USDC credit market, and converting eUSD to USDC** — not by waiting for Merkl to notice Elepan.
