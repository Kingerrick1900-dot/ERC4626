# FREEZE — loopholes previously bypassed ($2M idle)

**Mode:** FREEZE · info only · no broadcast  
**Correction:** Prior sheet over-indexed on park **USDC** util and dismissed other kingdom rails. Below are the real loopholes.

---

## L0 — Already sitting there (biggest miss)

**RSS/eUSD Morpho** `0x6075ba260df7fd5ad5bc9f1de33ac0bc2d8201dbe44b0081e89d9974f179867b`

| Fact | Live |
|--|--|
| Supply / borrow | ~**$1.101B** / ~**$1.057B** eUSD |
| **Unlatched idle now** | ~**$43.34M eUSD** |
| Util | ~**96.06%** |
| Sole borrower | HOT (borrow shares = 100% of book) |
| **Sole supplier** | **Landing** `0x5Adc…2357` (supply shares = 100%) |
| HOT free eUSD | ~**6.45M** |
| HOT gUSD (unwrap→eUSD 1:1) | ~**2.03B** (`unwrap`) |

**Loophole:** $2M unlatched idle **already exists** many times over — denominated in **kingdom eUSD**, owned by **Landing**, withdrawable up to the idle ceiling **without new USDC**.

Prior freeze path ignored this book because it is not Circle USDC and does not by itself raise `yRSS.maxWithdraw` on the USDC park.

---

## L1 — Instant +$2M eUSD idle (no Circle USDC, no flash)

HOT wallet already holds **> $2M eUSD**.

1. `Morpho.supply` **$2M eUSD** into `0x6075ba26…` onBehalf engineer/Landing  
2. **Do not borrow** that eUSD back  
3. Idle += $2M eUSD (on top of the $43M already there)

Optional fuel: `gUSD.unwrap` → eUSD (HOT owns gUSD; `eusd()` fixed).

**Status:** Executable under HOT key the moment freeze lifts. Not payroll Circle USDC.

---

## L2 — Cross-market asymmetric flash (USDC lasting idle)

FLASH-POLICY already allows: flash repay via **Morpho.borrow on a different book**.

```
flash USDC
→ supply USDC to PARK (0x41c08085…)     # lasting park idle += flash
→ borrow USDC from DEEP book (cbBTC/WETH) # repay flash
→ PARK idle stays
```

| Leg | Live gate |
|--|--|
| Deep USDC idle | cbBTC ~**$195M**, WETH ~**$10.8M** |
| Collateral for that borrow | **cbBTC / WETH** — HOT ≈ **0** (cbBTC dust 1028 wei) |
| Same-market borrow to repay | **Forbidden** (gasPark; re-latches) |

**Loophole is real in structure; blocked on collateral inventory**, not on Morpho math.

Sub-gate: DEX inventory → blue-chip coll (FLASH-POLICY allows). BRETT on HOT ≈ **$0.30**; free RSS on HOT **0** (posted); eUSD/USDC Uni **dust**.

---

## L3 — Borrow eUSD idle → try bridge to USDC (broken today)

```
borrow eUSD from L0 idle (RSS coll / headroom on 6075)
→ swap eUSD → USDC
→ engineerIdle USDC on PARK
```

| Leg | Live |
|--|--|
| eUSD borrow liquidity | ~**$43M** available |
| eUSD→USDC DEX | **dust** (Uni 100/500) |
| eUSD→WETH Uni | **no pool** |
| PSM eUSD listed | **No** (`NotListed`) |

Structure OK; **swap/PSM rail missing**. Listing eUSD on multi-PSM + seeding USDC is a separate king order (still needs USDC reserves to pay out).

---

## L4 — Rate magnet / own curator (zero king USDC)

Park + classic RSS at ~100% util = max borrow APY. Depositors supply USDC into yRSS / Morpho → lasting USDC idle appears.

Documented in `OWN-CURATOR-MOAT.md`. TVL empty until depositors arrive. Park often **unlisted** on Morpho API (`state: null`) — listing/magnet ops are the soft lever.

---

## L5 — Foreign PA maxIn (zero king USDC)

Gauntlet/Steakhouse **maxIn = 0**, park `reallocatableLiquidityAssets = 0`.  
Curator packet ≥ $2M maxIn → PA pull = lasting USDC idle. Soft/political loophole.

---

## L6 — Temporary USDC idle → unlock yRSS shares (payroll loophole)

```
flash USDC → repay park debt → yRSS.withdraw → Landing
→ withdraw HOT Morpho supply → repay flash
```

| Result | |
|--|--|
| Lasting park idle | **$0** |
| Landing Circle USDC | up to ~**$1.01M** (vault claim) |
| Named repay source | HOT supply withdraw + flash close — FLASH-POLICY OK |

This is the loophole if the *real* ask is spendable USDC, not a lasting $2M idle number on the park book.

---

## L7 — Play C buffer self-seed (needs USDC equity)

Supply USDC S, borrow ≤ S − **$2M** against RSS → lasting idle ≥ $2M.  
Equity required ≈ **$2M + borrowed**. No free lunch; flash+same-book borrow collapses to gasPark.

---

## Map ask → loophole

| King ask (precise) | Use | Blocker |
|--|--|--|
| **$2M unlatched idle (eUSD)** | **L0 already** / **L1 +$2M** | None under HOT/Landing |
| **$2M lasting USDC idle on park** | L2 (need cbBTC/WETH) · L4 magnet · L5 PA · L7 equity rail | Coll / depositors / maxIn / USDC |
| **~$1M Circle USDC on Landing** | **L6** flash-liberate shares | Freeze lift + key; not $2M |
| **$2M USDC via eUSD bridge** | L3 | DEX/PSM depth |

---

## What was bypassed before

1. Treated “idle” as **only** park USDC `0x41c08085…`  
2. Ignored Landing’s **$43M eUSD idle** on `0x6075ba26…`  
3. Ignored HOT **6.45M eUSD + gUSD unwrap** as instant L1 fuel  
4. Collapsed L2 (asymmetric flash) into gasPark instead of separating **repay market ≠ supply market**  
5. Dismissed L6 because it does not leave lasting idle — still the clean payroll loophole

---

## Freeze recommendation

- If ask = **unlatched idle $2M** in kingdom stables → **L0/L1** (already true / one supply tx).  
- If ask = **park USDC idle $2M for yRSS** → name **L2 collateral**, **L4/L5**, or **USDC rail**; do not re-gasPark.  
- If ask = **bills cash** → rename to **L6** (~$1.01M cap).

**No broadcast until King picks L0/L1 vs L2/L4/L5 vs L6.**
