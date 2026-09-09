# FREEZE — ALL 5 STEPS (canonical)

**Mode:** FREEZE · plan only · **no broadcast**  
**Lift freeze when King says:** `Build All` + **P4 coll** (cbBTC or WETH) + **P5 mint size** (e.g. 1B→5B ocean)  
**PR:** #131 · Branch `cursor/morpho-create-idle-2m-4f7f`

---

## What PR #131 already proved

| Proof | Detail |
|--|--|
| `CrownUnlatchIdle` | `0xEC847430Ac0667B75A0a0647a269ee286587FFC4` |
| Path | PSM sweep → `engineerIdle` (Morpho supply **only**, no borrow) |
| Park idle | **2 wei → $1.514572** |
| Util | **100% → 99.99%** |
| `yRSS.maxWithdraw(HOT)` | **2 → $1.51** |
| `minIdleBuffer` | Locks engineered idle so peel cannot re-latch |
| Hard block | `borrow` / `gasPark` revert |

That $1.51 is real unmatched **USDC** on the park book. Physics proven. Scale path below.

---

## Live rails (numbers)

| Rail | Fact |
|--|--|
| **L0 RSS/eUSD** `0x6075ba26…867b` | Unmatched idle ~**$43.3M eUSD** (not $2M — $2M is the **withdraw size**). Landing = sole supplier. HOT = sole borrower. |
| HOT free eUSD | ~**6.45M** (+ gUSD unwrap → eUSD) |
| yRSS claim | ~**$1.01M** USDC · park USDC idle now ~$1.51 |
| Deep USDC books (L2) | cbBTC ~$195M idle · WETH ~$10.8M idle |
| eUSD mint | HOT is **minter** (`isMinter=true`) · `mint(address,uint256)` |
| gUSD | HOT owner · `wrap` / `unwrap` vs eUSD · Aero stable pool `0x8C009d…` ~20M/20M |

---

## STEP 1 + 2 — eUSD idle → $4M liquid eUSD (FREE · no USDC · do first)

### Step 1 — L0 withdraw $2M

```
Landing → Morpho.withdraw(0x6075ba26…, 2_000_000e18, receiver=Landing)
```

- Uses existing unmatched eUSD idle (ceiling ~$43.3M).  
- **+$2M eUSD liquid on Landing.**  
- Signer: **Landing key** (sole supplier).  
- Kill: do not re-borrow that eUSD on the same book.

### Step 2 — L1 supply $2M then withdraw to Landing

```
HOT → Morpho.supply(0x6075ba26…, 2_000_000e18)   # unmatched; do not borrow
HOT → Morpho.withdraw(..., receiver=Landing)       # +$2M eUSD to Landing
```

- Fuel: HOT free eUSD (or `gUSD.unwrap` first).  
- Landing liquid eUSD total: **$4M**.  
- Book idle returns to ~$41.3M after the second withdraw (net: moved $2M HOT eUSD → Landing via the book).  
- No Circle USDC. No flash.

**P1–P2 = eUSD rail. Ready when Landing + HOT sign.**

---

## STEP 3 — Landing ~$1.01M USDC payroll (scale proven Unlatch physics)

**Primary (no USDC sitting on HOT):** Flash **L6**

```
flash USDC (~$1.01M + dust)
→ Morpho.repay(park 0x41c08085…, amt, onBehalf=HOT)   # opens idle
→ yRSS.withdraw(amt, Landing, HOT)                      # Circle USDC → Landing
→ Morpho.withdraw(HOT park supply → flash repay)        # named repay source
```

| Rule | |
|--|--|
| Cap | ≤ yRSS claim ≈ **$1.01M** |
| Repay | HOT park **supply** withdraw — **not** park borrow |
| Kill | flash+gasPark / borrow park to repay = **abort** (hard-blocked on Unlatch contracts) |

**Alternate only if HOT already holds ~$1M USDC:**  
`CrownUnlatchIdle.unlatchRepay(~1e6)` then peel — same equity identity; does **not** invent USDC. Prefer Flash L6 when HOT USDC = 0.

**Note:** Flash L6 leaves **$0 lasting** park idle (expected). Payroll is the deliverable. Lasting USDC idle = Step 4.

Pre: `yRSS.approve(executor, max)` from HOT.

---

## STEP 4 — $1.5M LASTING USDC idle + buffer

Temp idle from Step 3 vanishes after flash close. Lasting idle needs **asymmetric L2**:

```
acquire cbBTC or WETH coll (≥ ~$1.75M notional @ ~86% LLTV for $1.5M borrow)
flash 1.5M USDC
→ createIdle / engineerIdle on PARK (supply only)
→ borrow USDC on cbBTC or WETH book (deep idle)
→ repay flash with that borrow
→ PARK keeps $1.5M unmatched USDC idle
→ minIdleBuffer = 1.5M (yRSS can unlock; peel cannot eat the buffer)
```

| Gate | |
|--|--|
| **P4 coll name required before fire** | `cbBTC` **or** `WETH` (+ source: OTC / treasury / post-payroll buy) |
| Repay market | **≠** park (else gasPark) |
| After | Lasting **$1.5M USDC idle** · yRSS stays unlockable under buffer |

---

## STEP 5 — Ocean → attract USDC → L2 scale toward $200M lasting idle

```
Mint ocean eUSD/gUSD (HOT minter/owner)
→ seed Aero eUSD/gUSD both sides (start from pool 0x8C009d…; target depth thesis 1B→5B)
→ magnet: depth + eUSD/USDC + PegKeeper/AMO
→ arbs / LPs bring real Circle USDC
→ every inbound USDC → LitePSM / engineerIdle / createIdle → pull100 → Landing
→ L2 loop scales lasting idle toward ~$200M
```

| Law | |
|--|--|
| Mint ≠ USDC | Ocean is kingdom stables; USDC **walks in** |
| No gasPark recycle | Inbound USDC stays unmatched or peels to Landing |
| Soft levers | Foreign PA maxIn · rate magnet on park/rss40 |

---

## Fire order (when freeze lifts)

1. **Fire P1 → P2** → $4M eUSD liquid on Landing  
2. **Fire P3** (Flash L6) → ~$1.01M USDC payroll on Landing  
3. **P4 coll named** → fire asymmetric L2 → $1.5M lasting USDC idle + buffer  
4. **P5 mint size named** → ocean seed → magnet → L2 scale loop  

**Parallelism:** P1–P2 (eUSD) and P3 (USDC payroll) are parallel *rails* but fire **in order** as listed once armed. P4 after coll name. P5 after mint size name.

---

## Lift-freeze passphrase (King)

Say exactly:

```
Build All
P4 coll = <cbBTC|WETH> source = <OTC|treasury|other>
P5 mint size = <e.g. 1B eUSD / wrap gUSD / pool target 5B>
```

Until then: **no broadcast · no mint · no flash · no pool seed.**

---

## Kill list

- gasPark / same-book borrow to repay flash  
- Claiming mint ocean = Circle USDC idle  
- Dump eUSD core into dust Uni for USDC fills  
- Re-latch lasting idle by peeling through `minIdleBuffer`  
- Phase 1 with HOT key only (Landing must sign withdraw)

---

## One-block copy

```
FREEZE ALL-5
P1 Landing withdraw 2M eUSD from 6075ba26 (idle ceiling ~43M)
P2 HOT supply 2M eUSD → withdraw Landing (=4M eUSD liquid)
P3 Flash L6 → ~1.01M USDC Landing (repay=HOT park supply withdraw)
P4 NAME coll cbBTC|WETH → L2 asymmetric → 1.5M lasting USDC idle + buffer
P5 NAME mint 1B→5B ocean → attract USDC → L2 scale ~200M lasting idle
LIFT = "Build All" + P4 coll + P5 size
```
