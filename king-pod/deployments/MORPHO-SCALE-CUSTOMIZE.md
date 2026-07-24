# Pre-Loan Upgrade — Morpho customization (user-independent scale)

**Status:** STRUCTURE PREP. No live broadcast until `LIVE_ARMED=1` + King GO.  
**Loan remains Morpho Blue.** ZK is pack only. KEEP USDC never recycles into yELE/yRSS.

---

## Current yRSS allocation (live Base)

Vault `0xF80C0529bD94C773844E459853CD91B9263dD525` · asset USDC  
Owner/curator/allocator: **hot** · fee **10%** → **Landing** · guardian **0**

| Market | Coll | Cap | Enabled | Vault supply (≈ USDC) |
|--|--|--:|--:|--:|
| `0x40ac09…b794` | RSS @ 77% | $14M | yes | **~$0** (dust shares) |
| `0x3a5ba1…4126` | RSS @ 91.5% | $14M | yes | **$0** |
| `0x9103c3…1836` | **cbBTC** @ 86% | $14M | yes | **$0** |
| `0x8793cf…1bda` | **WETH** @ 86% | $14M | yes | **$0** |
| `0xf6f43f…8c16` | **BRETT** @ 62.5% | $2M | yes | **~$0.35** (≈100% of TVL) |
| ELE/USDC `0xa4ec…da53fc` | Elepan | — | **no** | not listed |

**TVL ≈ $0.35 USDC.** Almost all in BRETT. cbBTC/WETH caps are live but **unfunded**.

Supply queue order: RSS77 → RSS91.5 → cbBTC → WETH → BRETT  
Withdraw queue: RSS77 → cbBTC → WETH → BRETT → RSS91.5

---

## Documented Morpho levers (map → Kingdom)

### 1) Curator-controlled allocation
Morpho: curator sets caps/queues; allocator `reallocate` moves USDC across enabled markets without waiting on new users ([curate allocations](https://docs.morpho.org/curate/tutorials-v1/manage-allocations/)).

**Kingdom customize (pre-loan):**
- Keep feeRecipient = Landing (done).
- Target stack when capital arrives: **cbBTC → WETH first**, BRETT last (or cap cut).
- Optional: enable ELE market on yRSS only for **third-party** borrow demand — **never** as recycle of Landing KEEP.

### 2) Isolated markets + flash seeding
Morpho: `flashLoan` from global inventory; supply into isolated market to bootstrap idle ([flash loans](https://docs.morpho.org/learn/concepts/flashloans/)).

**Kingdom customize:**
- Flash seed ELE/USDC opens idle for the **Morpho loan** (`borrow` → Landing).
- Same-tx flash supply + borrow-to-repay-flash ⇒ **net KEEP ≈ 0** (machinery, not cash printer).
- Real KEEP still needs idle left after seed **or** owned USDC seed + `borrowPortion` without recycle.

### 3) Fees / incentives (vault “hooks”)
Morpho: performance fee on MetaMorpho; Merkl/rewards external for TVL bootstrap.

**Kingdom customize:**
- yRSS fee 10% → Landing (live).
- yELE fee → Landing at GO.
- Merkl campaigns = optional TVL bait; not required for Morpho `borrow`.

---

## Pre-loan structure (order of ops)

```text
A. Curator book (yRSS)
   - Report allocation (this sheet)
   - Plan reallocate: BRETT → cbBTC/WETH when TVL > dust
   - Do not ENABLE ELE on yRSS for KEEP recycle

B. Morpho loan (ELE/USDC) + ZK pack
   - Coll on hot · borrowPortion → Landing
   - PreSelfLiq armed
   - Gate pack on actions

C. Passive diverse → Landing
   P1 yRSS fee | P2 yELE fee@GO | P3 Blue APY (external) | P4 skim | P5 ZK credit rail | P6 Uni optional

D. Scale without users
   - Curator reallocate inside yRSS
   - Flash/Blue seed ELE market when King arms
   - Loan function draws portions against room ∩ idle
```

---

## Next customize (when King says GO)

1. `reallocate` yRSS off BRETT into cbBTC/WETH (meaningful only after TVL ↑).  
2. Optional Merkl on yRSS.  
3. Morpho loan fire: KeepDraw + PreSelfLiq + pack (`LIVE_ARMED`).  
4. Flash/Blue seed ELE only under explicit arm — KEEP stays on Landing.

---

## Commands (no broadcast)

```bash
forge script script/FireYrssCuratorPrep.s.sol:FireYrssCuratorPrep --rpc-url $BASE_RPC
forge script script/FireElepanLoanPrep.s.sol:FireElepanLoanPrep --rpc-url $BASE_RPC
```
