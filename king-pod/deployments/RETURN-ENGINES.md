# RETURN ENGINES — create funds, don't beg the King

**King order:** Stop dishing out with nothing back. No more "send USDC to hot." **Build shit. Create the funds.** Same playbook elites use — **legal structure**, not charity.

---

## Money out vs money in (honest ledger)

| OUT (Kingdom spent) | IN (must engineer) |
|---------------------|-------------------|
| Gas on fires | Desk/bond **buyer USDC** → Landing |
| Morpho **borrow interest** (BRETT ~$0.30 position) | **Borrowers pay** yRSS lenders + **10% fee** to King |
| RSS stocked on desk/bond (inventory, not loss) | Counterparty **pays USDC** for RSS |
| yRSS USDC supplied to books | **Utilization yield** + fee when util > 0 |

**Rule:** Every new OUT fire needs a named **IN engine** on the same doc before broadcast.

---

## Live IN engines (no debit card required)

### 1) DESK @ $1 — **LIVE**
- **700k RSS** listed · helper `fillPhase1()`
- **IN:** buyer USDC → Landing
- **Packet:** `OUTBOUND-DUAL-RAIL.md`

### 2) BOND @ $0.97 — **LIVE**
- **520k RSS** @ discount
- **IN:** urgency buyers → Landing
- **Same packet**

### 3) CAPTURE IDLE — **shelf, armed**
- **1M RSS** posted RSS77 · **~$700k** soft borrow capacity
- When RSS or BRETT Morpho **idle ≥ size** → `FireCashLeg500` / `FirePhase1FiveHundred` → Landing
- **Script:** `script/opportunity-capture.sh` (RSS) · `script/capture-all-idle.sh` (RSS + BRETT)

### 4) yRSS FEE METER — **LIVE contract, needs util**
- **10%** performance fee → King
- **IN:** when strangers borrow against your supplied USDC / PA routes depth
- BRETT book now has **~$7.57** supply · borrow active → interest flows when util rises

### 5) BRETT RAIL — **LIVE, proven**
- Buy BRETT → post → borrow → Landing
- **IN:** scales with ETH/USDC seed **from borrow proceeds + external LPs**, not King debit
- **Re-fire:** `FireFinishBrett.s.sol` when hot has gas/seed

---

## Build queue (scribe — no broadcast until King FIRE)

| # | Engine | Creates | Status |
|---|--------|---------|--------|
| A | **Aerodrome Ignition** | USDC LPs via RSS vote bribes | Plan + `FireAeroIgnition.s.sol` shelf |
| B | **Dutch bond window** | Time-pressure discount on `CrownRssBond` | Code tweak + packet |
| C | **Dual capture daemon** | Auto-borrow when RSS **or** BRETT idle ≥ threshold | `capture-all-idle.sh` |
| D | **Return scoreboard** | Landing in vs gas/interest out | `return-path-status.sh` |
| E | **LP asymmetric seed** | RSS-heavy pool → accumulate USDC leg | Phase 2 sim |

---

## Elite playbook (legal)

Same moves Steaks / Olympus / Aerodrome used — **not** hacks:

1. **Sell your token** (desk, bond) — you are the issuer  
2. **Borrow against your token** when **someone else supplied USDC** (Morpho capture)  
3. **Bribe emissions** with token supply (Ignition)  
4. **Tax utilization** (yRSS fee, curator spread)  
5. **Discount urgency** (bond < desk peg)  

**Forbidden:** flash payroll lies · intentional dust debt · "wait for Gauntlet" · asking King for hot USDC when RSS can stock a rail

---

## Tomorrow vs tonight

| King tomorrow (optional) | Scribe tonight (no card) |
|--------------------------|---------------------------|
| Load debit → hot ETH/USDC | Finish capture scripts + Ignition shelf |
| Upsize BRETT finish | Return scoreboard on every check-in |
| | Keep outbound packets warm |

**Right.** We work. King rests. Scribe builds the IN side.
