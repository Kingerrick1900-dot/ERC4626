# FREEZE PLAN — King 5-step idle → payroll → ocean

**Mode:** FREEZE · plan only · **no broadcast · no mint · no flash** until King lifts freeze  
**Branch:** `cursor/morpho-create-idle-2m-4f7f`  
**Refs:** `FREEZE-2M-IDLE-LOOPHOLES.md` · `FLASH-POLICY.md` · `UNLATCH-IDLE-LIVE.md`

---

## End-state scoreboard

| Phase | Deliverable | Asset |
|--|--|--|
| 1–2 | **$4M liquid eUSD on Landing** | kingdom eUSD |
| 3 | **~$1.01M Circle USDC on Landing** | payroll today |
| 4 | **$1.5M lasting USDC idle on park** + yRSS unlocked | Morpho USDC |
| 5 | **Ocean pools → attract USDC → L2 scale to ~$200M lasting idle** | magnet + asymmetric flash |

---

## Live anchors (do not re-litigate)

| Item | Address / fact |
|--|--|
| HOT | `0x6708…a7d1` |
| Landing | `0x5Adc…2357` |
| RSS/eUSD book (L0) | `0x6075ba26…867b` · idle ~**$43.3M eUSD** · supplier=**Landing** · borrower=HOT |
| USDC park (yRSS) | `0x41c08085…` · idle ~**$1.51** · yRSS claim ~**$1.01M** |
| CrownUnlatchIdle | `0xEC84…FFC4` |
| gUSD | `0x319A…bc5d` · unwrap→eUSD · HOT owner |
| eUSD | `0xE8aA…af8a` · `mint` / `setMinter` · HOT owner |
| Deep USDC idle (L2) | cbBTC ~$195M · WETH ~$10.8M |
| HOT free eUSD | ~**6.45M** (covers Phase 2 supply) |

---

## Phase 1 — Withdraw L0 $2M eUSD → Landing (free)

**Physics:** Landing already owns 100% of Morpho supply on `0x6075ba26…`. Idle ≥ $43M ⇒ `withdraw(2e6 eUSD)` succeeds without new capital.

```
Landing (msg.sender) → Morpho.withdraw(RSS/eUSD, 2_000_000e18, 0, Landing, Landing)
```

| Check | Gate |
|--|--|
| Signer | **Landing key** (not HOT) — only supplier can withdraw own shares |
| Idle before | ≥ $2M eUSD |
| Idle after | ~$41.3M eUSD |
| Landing liquid eUSD | **+$2M** |
| Kill | Do **not** borrow the withdrawn eUSD on the same book |

**Freeze note:** This agent session has HOT key only. Phase 1 waits on Landing signer.

---

## Phase 2 — Supply L1 $2M → pull another $2M → Landing **$4M** liquid eUSD

**Physics (stacked on Phase 1):**

```
HOT → Morpho.supply(RSS/eUSD, 2_000_000e18, onBehalf=HOT)   # idle +$2M (back ~$43.3M)
HOT → Morpho.withdraw(..., receiver=Landing)                 # idle −$2M; Landing +$2M
```

| Check | Gate |
|--|--|
| Fuel | HOT free eUSD ≥ $2M **or** `gUSD.unwrap` first |
| Same-tx OK? | Yes: supply then withdraw to Landing |
| Landing liquid eUSD **total** | **$4M** (Phase1 $2M + Phase2 $2M) |
| Book idle after | ~$41.3M still (net flat vs post-Phase1) |
| Kill | No borrow against the supplied eUSD in the same path |

**Optional order tweak:** supply onBehalf=Landing, then Landing withdraws — same net, needs Landing for withdraw leg.

---

## Phase 3 — Flash L6 → ~$1.01M USDC payroll today

**Physics:** Temporary park idle → peel yRSS → repay flash from HOT Morpho USDC supply withdraw (matched deleverage). FLASH-POLICY: named repay = HOT supply withdraw.

```
flash USDC (~$1.01M + dust)
→ Morpho.repay(park, amt, onBehalf=HOT)          # opens idle
→ yRSS.withdraw(amt, Landing, HOT)               # Circle USDC → Landing
→ Morpho.withdraw(park supply, HOT → flash repay)
```

| Check | Gate |
|--|--|
| Signer | HOT |
| Cap | ≤ `yRSS.convertToAssets(balanceOf(HOT))` ≈ **$1.01M** |
| Pre | `yRSS.approve(liberator/puller, max)` |
| Lasting park idle | **$0** (expected) |
| Landing Circle USDC | **+$1.01M** payroll |
| Kill | Do **not** repay flash by borrowing park (gasPark) |

**Deliverable:** bills cash. Does **not** replace Phase 4 lasting USDC idle.

---

## Phase 4 — cbBTC/WETH collateral → L2 **$1.5M** lasting USDC idle

**Physics (asymmetric flash — repay market ≠ supply market):**

```
acquire ≥ $1.5M / LLTV cbBTC or WETH coll (≈ $1.75M+ @ 86% LLTV)
flash USDC 1.5M
→ Morpho.supply(PARK, 1.5M) onBehalf=CrownUnlatchIdle   # lasting idle
→ Morpho.supplyCollateral + borrow(USDC) on cbBTC or WETH book
→ repay flash
→ setMinIdleBuffer(1.5M) so peel cannot re-latch
```

| Check | Gate |
|--|--|
| Coll source | OTC / treasury / DEX of **non-core** inventory — **not** gasPark |
| Doctrine | Prefer **loan RSS/ELE**, keep eUSD core; coll should be blue-chip (cbBTC/WETH) |
| Park idle after | **+$1.5M USDC lasting** |
| yRSS | `maxWithdraw` opens ≥ min(claim, idle); keep buffer so idle **stays** |
| Kill | Borrowing the park idle to repay flash = **abort** |

**Collateral acquisition options (King picks before fire):**

1. OTC buy cbBTC/WETH with Phase-3 USDC slice (shrinks payroll — explicit trade)  
2. External treasury / MM desk posts coll  
3. Later Phase-5 USDC inflow buys coll then loops L2 larger  

---

## Phase 5 — Mint ocean → pools → attract USDC → L2 to ~$200M idle

**Intent:** Kingdom stables as **magnet**, not as fake Circle USDC.

### 5a — Mint authority (kingdom)

| Token | Owner | Mint path |
|--|--|--|
| eUSD | HOT | `setMinter(HOT,true)` if needed → `mint(to,amt)` |
| gUSD | HOT | `wrap(eUSD)` after mint (gUSD backs with eUSD) |

**Ocean size (King numbers):** mint path toward **1B** notionals; target **eUSD/gUSD pool depth ~5B** (Aero stable `0x8C009d…` already ~20M/20M — scale by seeding).

### 5b — Attract external **Circle USDC** (~$200M thesis)

USDC enters via: LP incentives, OTC, PSM listing + reserves, Morpho rate magnet on park/rss40, foreign PA maxIn.

**Honest gate:** minting eUSD/gUSD does **not** mint USDC. USDC must walk in from outside.

### 5c — L2 loop to ~$200M lasting USDC idle

Once USDC + blue-chip coll (or foreign PA) exist:

```
repeat L2 (or direct engineerIdle / PA reallocate)
until park (or chosen USDC book) lasting idle ≈ $200M
keep minIdleBuffer / util buffer — never self-borrow idle to 100%
```

| Kill | |
|--|--|
| Recycle USDC payroll back into gasPark | Forbidden (`NO-RECYCLE-UNTIL-EXIT`) |
| Claim ocean mint = USDC idle | False — refuse |
| Foreign maxIn still 0 and no USDC rail | $200M idle blocked |

---

## Dependency graph

```
Phase1 (Landing key) ──┐
                       ├──► $4M eUSD liquid on Landing
Phase2 (HOT eUSD) ─────┘
                       │
Phase3 (HOT flash L6) ──► +$1.01M USDC payroll     [parallel OK after freeze lift]
                       │
Phase4 ◄── need cbBTC/WETH coll (external or slice of USDC)
                       │
Phase5 mint ocean ──► pools ──► attract USDC ──► scale L2 ► $200M lasting idle
```

Phases **1–2** and **3** are independent rails (eUSD vs USDC).  
Phase **4** needs coll. Phase **5** needs external USDC gravity.

---

## Freeze checklist (before any fire)

1. King confirms Landing will sign Phase 1 (or custody move).  
2. King confirms Phase 3 payroll size ≤ yRSS claim.  
3. King names Phase 4 coll source (OTC / treasury / post-USDC buy).  
4. King confirms Phase 5 mint size + pool venue (Aero) + USDC attraction thesis (PA packet / OTC / magnet).  
5. Env: `KING_GO=1` only after freeze lift; flash paths set `FLASH_ALLOWED=1` + `REPAY_SOURCE=…`.  
6. Rotate HOT key (pasted in prior session) before large mint/ocean.

---

## Explicit non-goals this plan

- gasPark / same-book flash borrow to “make” USDC idle  
- Treating eUSD/gUSD mint as Circle USDC  
- Dumping eUSD core for dust Uni USDC fills  
- Re-locking freed USDC into matched self-borrow

---

## One-block copy

```
FREEZE 5-STEP
P1 Landing withdraw 2M eUSD from 6075ba26 (Landing key)
P2 HOT supply 2M eUSD → withdraw to Landing (=4M eUSD liquid)
P3 Flash L6 → ~1.01M USDC Landing payroll (repay=HOT park supply withdraw)
P4 Get cbBTC/WETH → asymmetric L2 → 1.5M lasting USDC idle + buffer
P5 Mint ocean eUSD/gUSD → 5B pools → attract 200M USDC → L2 scale lasting idle
NO gasPark · NO broadcast until King lifts freeze
```
