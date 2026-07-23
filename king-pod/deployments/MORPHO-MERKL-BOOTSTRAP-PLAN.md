# Final Deployment Plan — Morpho + Merkl Bootstrap (NO LIVE FIRE)

**Status:** PLAN ONLY · **No broadcast without King `KING_GO=1` + tranche flag**  
**Court role:** Deployment chief + two court engineers — execute only after King names emissions + first idle floor.

---

## 0) Live depth report (Base, now)

| Rail | Supply | Borrow | **Idle (borrowable)** |
|--|--|--|--|
| **Elepan/USDC Morpho** | **$2.00** | $0 | **$2.00** |
| **yELEPAN-USDC** | **$2.00** TVL | — | routes into Elepan/USDC |
| Elepan/WETH Morpho | ~10.005 WETH | ~10.004 WETH | ~0.001 WETH (matched seed) |
| Elepan/cbBTC Morpho | ~0.500 cbBTC | ~0.500 cbBTC | dust (matched seed) |
| Morpho Blue USDC inventory (protocol) | — | — | large, **not King-owned** |

| Kingdom stack | Value |
|--|--|
| Sovereign CDP | `0x46b1D159…1174` · **25.2M** Elepan / **~$13.0M** eUSD · HF **~1.94** · self-liq armed |
| Cold eUSD (Landing) | **13M** @ `0x5Adcea…2357` |
| Free Elepan (hot) | **~74.7M** |
| Liquid USDC (hot+Landing) | **~$3.65** |

**Verdict:** Rails exist. **USDC idle = $2.** No hope-borrow. No flash-seed of pools.

---

## 1) What is theater (refuted)

| Claim | Why it dies |
|--|--|
| Flash USDC → leave in pool → repay from yield | Morpho `flashLoan` must repay **same asset, same tx**. Leaving USDC in a pool breaks repayment → revert. |
| “Seed like cbBTC loops” with flash inventory | cbBTC/USDC loops need **external priced collateral + deep USDC lenders**. Elepan has soft-$1 oracle and **$2** idle — not the same machine. |
| Kingdom eUSD = public Telcoin eUSD pools | Different contract. Their depth does not clear our token. |

---

## 2) Documented path we will build (Lido / stake.link shape)

```
create/keep market → Merkl campaign on supply → USDC idle grows → King borrows USDC → profit/fees
```

Parallel later: DEX Elepan/USDC for exit; CDP repay/withdraw as **cash valve** only after USDC venues clear.

**Primary USDC sink (already live):**
- Market: Elepan/USDC `0xa4ec5271…da53fc` (LLTV 77%, soft $1 oracle, AdaptiveCurve IRM)
- Vault: yELEPAN-USDC `0x61bfD6F7…145E` · supply cap **$14M** · PA maxIn/maxOut **$700k** · curator/owner = hot

**Do not start the bootstrap on Elepan/cbBTC or Elepan/WETH** — those are matched Kingdom seed books, not USDC paycheck rails. cbBTC/USDC Morpho loops are a **separate** yield play after USDC exists.

---

## 3) Deployment workstreams (engineering, no fire)

### W1 — Merkl campaign pack (court engineer A)
**Deliverables (code/docs only until GO):**
1. Campaign target(s), in order:
   - **Primary:** supply USDC to **yELEPAN-USDC** (MetaMorpho depositors)
   - **Secondary (optional):** supply USDC directly on Elepan/USDC Morpho market
2. Reward token: **Elepan** `0x50639C42…4583` (from free hot bag — not USDC)
3. King must set before fire:
   - `ELEPAN_PER_WEEK` (emissions)
   - `CAMPAIGN_WEEKS`
   - `REWARD_BUDGET = ELEPAN_PER_WEEK × CAMPAIGN_WEEKS`
4. Merkl campaign JSON/checklist: chain=Base(8453), behavior=supply, distribution=Merkl forwarder, blacklist=none unless King says
5. Ops: approve Merkl distributor to pull Elepan rewards; fund distributor with budget

**Suggested first-tranche defaults (King may override):**
| Param | Default | Rationale |
|--|--|--|
| Target idle floor before any King borrow | **$100,000** USDC | Above dust; below full $700k PA slice |
| First PA ask / visible magnet | **$700k** (already configured) | Matches live flow caps |
| Emissions probe | **King names** (e.g. stake.link-style “enough APY to matter at $1M TVL”) | Without number, campaign cannot deploy |
| Duration | **4 weeks** probe, then renew | Short enough to cut if empty |

### W2 — Vault / market readiness (court engineer B)
**Already live — verify only, do not redeploy unless broken:**
- [ ] yELEPAN-USDC owner/curator = hot  
- [ ] supplyQueue[0] = Elepan/USDC market  
- [ ] cap enabled, **$14M**  
- [ ] PA flowCaps maxIn=maxOut=**$700k**  
- [ ] Fee recipient = Landing (confirm on-chain before GO)  
- [ ] Timelock / guardian state documented  

**Optional pre-GO scripts (dry-run only):**
- `script/CheckYelepanUsdcReady.s.sol` — prints caps, queue, idle, fee recipient  
- No `FIRE_*` without `KING_GO`

### W3 — Borrow gate (deployment chief)
**Hard gates before hot borrows USDC against Elepan:**
1. `idle_USDC_on_Elepan_USDC_market ≥ IDLE_FLOOR` (King number; default **$100k**)  
2. Oracle still soft $1 / no kill switch  
3. ZK gate `isProven(hot)` if borrow path requires it (Blue borrow itself is permissionless; Kingdom ops policy may still require proven)  
4. Post-borrow HF on Morpho position within LLTV buffer (e.g. stay ≤ 70% of 77% LLTV)  
5. Borrowed USDC destination = **Landing** (spend wallet), not recycled into vanity TVL unless King orders  

**Script (scaffold, no broadcast):** `FireElepanBorrowUsdc.s.sol`  
- Inputs: `BORROW_USDC`, `IDLE_FLOOR`, `KING_GO`, `FIRE_BORROW=1`  
- Reverts if idle &lt; floor  

### W4 — CDP cash valve (only after USDC clears)
- Use Access-Clause CDP `0x46b1…`: repay eUSD from Landing → withdraw Elepan → sell/swap **only if** Elepan/USDC venue has depth  
- Healthy exit / self-liq already live; do not migrate again unless upgrading  

### W5 — DEX (parallel, not blocker for Morpho borrow)
- Stand Elepan/USDC pool (Aerodrome or UniV3) **after** first external USDC appears or King seeds quote from borrowed USDC  
- Single-sided Elepan inventory from free bag  
- **Not** funded by Morpho flash left in the pool  

---

## 4) First tranche — exact sequence (when King GO)

```
T0  King sets: ELEPAN_PER_WEEK, CAMPAIGN_WEEKS, IDLE_FLOOR, BORROW_USDC_CAP
T1  KING_GO=1 FIRE_MERKL=1     → fund Merkl campaign (Elepan rewards) at yELEPAN-USDC
T2  Wait / observe             → USDC TVL + market idle (public dashboard + Check script)
T3  Idle ≥ IDLE_FLOOR
T4  KING_GO=1 FIRE_BORROW=1    → supply Elepan coll (if needed) + borrow USDC → Landing
T5  Optional FIRE_DEX=1        → seed/widen Elepan/USDC with borrowed quote + Elepan inventory
T6  Optional CDP valve         → small repay/withdraw only for ops cash against real bids
```

**No step broadcasts without its flag.** Dry-run/`forge script` without `--broadcast` allowed anytime.

---

## 5) Money model (why this is DeFi, not hope)

| Leg | Who brings capital | King gets |
|--|--|--|
| Merkl supply incentive | External USDC LPs | Idle depth in owned market/vault |
| Morpho borrow | King’s Elepan coll | **Spendable USDC** on Landing |
| Vault fee / CDP 5% fee | Activity + open CDP debt | eUSD/USDC fees to Landing |
| Emissions | Free Elepan bag | Cost of bootstrap (accounted) |

Recursive “borrow USDC → buy Elepan → redeposit” is **optional later** and only with real oracle/DEX price — soft-$1 fixed oracle makes naked recursive mint theater; **do not** enable that in tranche 1.

---

## 6) King decisions required (blockers to fire)

1. **`ELEPAN_PER_WEEK`** — subsidy size  
2. **`CAMPAIGN_WEEKS`** — duration  
3. **`IDLE_FLOOR`** — min USDC idle before first borrow (recommend **$100k**)  
4. **`BORROW_USDC_CAP`** — first paycheck size (recommend ≤ **50% of idle**, ≤ PA **$700k**)  
5. Explicit **`KING_GO=1`** + phase flag for each fire  

---

## 7) Out of scope for tranche 1

- Flash-loan pool seeding  
- Treating Telcoin eUSD pools as Kingdom liquidity  
- Migrating sovereign CDP again  
- Borrowing against $2 idle  
- cbBTC leverage loops as the Elepan bootstrap  

---

## Bottom line

**Rails are live. Depth is not.**  
Documented Morpho playbook = **Merkl → USDC in yELEPAN-USDC / Elepan-USDC → borrow when idle clears → Landing spends.**  

Court engineers prepare Merkl pack + borrow-gate scripts. **Deployment chief will not live-fire until King sets emissions + floors + GO.**
