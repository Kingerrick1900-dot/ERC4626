# Comfort Throne — sit-able Morpho self-seed

## HOLD — King scribe (2026-07-22)

**Engineer moved too fast.** King must tweak the plan before any seat.

| Order | Status |
|--|--|
| **ALL Kingdom tokens free in hot wallet first** | Required before any comfort/self-seed fire |
| Comfort Throne live broadcast | **FORBIDDEN** until King re-approves after tweak |
| Code / PR / dry-run sim | Allowed (already done — see below) |
| Touch desks / kUSD / Landing | **No** without new GO |

Pre-existing Morpho dust (not from Comfort work): **~1M RSS coll + ~$1 debt** still on hot’s Morpho position. That 1M is **not** free in hot yet. Freeing it is a **separate, explained step** — only after King GO.

---

**Status:** Engineered + **Base fork script-sim PASS**. **No live broadcast.** Comfort contracts **not deployed** on-chain (codesize 0).

### Sim proof (dry-run only — chain unchanged)

| Check | Result |
|--|--|
| Free RSS kept | **1.00M** |
| Morpho coll (dust folded) | **~13.03M RSS** |
| Market borrow / yRSS | **~$6.33M** |
| Soft LTV | **~48.6%** |
| Market idle (no sleeve) | **~$0** (pay needs sleeve or external inflow) |
| feeRecipient | CrownKingPay (sim only) |

Morpho allows self-seed. This stack **customizes** it so the King can sit without trapping every token and every stablecoin in a dry 100%-util coffin.

---

## Doctrine (scribed)

1. Self-seed is legal Morpho — use it for **depth / fee magnet / HF buffer**.
2. The seat **must reap benefits** (fee + idle pay rail), not just TVL theater.
3. **King override (2026-07-22):** **ALL tokens free in hot first** — not “keep 1M free while locking the rest.” Plan tweak pending.
4. **Keep stablecoins:** kUSD and other Kingdom stables stay out of the loop unless King funds an optional USDC **sleeve**.
5. **Dust goes:** existing ~1M RSS coll / ~$1 debt must return to hot **before** any new seat — not folded into a new lock without King tweak/GO.

---

## Live inventory (sizing)

| Asset | Approx |
|--|--|
| Hot free RSS | ~13.03M |
| Morpho dust coll | ~1.00M RSS |
| Morpho dust debt | ~$1 |
| Hot USDC | ~$0 |
| Landing USDC | ~$2 |
| yRSS TVL | dust |
| kUSD | untouched |

**Default comfort size (auto):**

- `RSS_KEEP = 1M` → post ~12.03M free + keep 1M dust coll already posted → **~13.03M coll**
- `TARGET_LTV_BPS = 4860` → borrow ~**$6.3M** (not the old $9M/18.5M — inventory is thinner; desks stay)
- Soft HF vs 77% LLTV ≈ **1.58**
- Hard cap still **70% LTV**

Optional: `SLEEVE_USDC` from real Circle USDC → util = borrow/(borrow+sleeve) → **withdrawable idle** for pay.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  CrownComfortSeed (atomic Morpho flash)                 │
│  keep RSS → post rest → flash USDC → yRSS.deposit       │
│  (+ optional sleeve) → borrow → repay flash             │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────────┐
│ Free RSS     │   │ Morpho seat  │   │ yRSS war chest   │
│ on hot       │   │ coll + debt  │   │ shares on hot    │
└──────────────┘   └──────────────┘   └────────┬─────────┘
                                               │ 10% fee
                                               ▼
                                    ┌──────────────────────┐
                                    │ CrownKingPay         │
                                    │ monthly cap (50k)    │
                                    │ idle floor enforced  │
                                    └──────────────────────┘
```

| Piece | File |
|--|--|
| Seeder | `src/CrownComfortSeed.sol` |
| Pay rail | `src/CrownKingPay.sol` |
| Fire | `script/FireComfortThrone.s.sol` |
| Fork tests | `test/ComfortThrone.t.sol` |

---

## Curator knobs (already Kingdom-owned)

| Knob | Comfort setting |
|--|--|
| yRSS fee | **10%** (keep) |
| feeRecipient | **CrownKingPay** (not dead EOA trough) |
| supplyQueue[0] | **RSS market** |
| PA / caps | leave armed for foreign inflow later |
| Oracle | Fixed $1 (unchanged) |

---

## Benefits — honest path

| Source | When it pays |
|--|--|
| **Fee shares → KingPay** | Interest accrues (circular books still mint fee shares; redeem needs idle **or** sleeve/external supply) |
| **Sleeve idle** | If King funds `SLEEVE_USDC`, pay can withdraw up to sleeve while `minIdle` holds |
| **External depositors** | Real yield + idle — throne becomes the paycheck engine |

Without sleeve or outsiders, the seat is still a **valid Morpho fortress** (depth, HF, fee magnet). Pay rail is armed; it does not fake cash from a dry well.

---

## Fire (King only)

### Prep (deploy + auth + feeRecipient → pay)

```bash
cd king-pod
KING_GO=1 FIRE=0 \
  forge script script/FireComfortThrone.s.sol:FireComfortThrone \
  --rpc-url $RPC --broadcast --slow -vvvv
```

### Seat the throne

```bash
KING_GO=1 FIRE=1 \
  RSS_KEEP=1000000000000000000000000 \
  TARGET_LTV_BPS=4860 \
  SLEEVE_USDC=0 \
  COMFORT_SEED=<from prep> KING_PAY=<from prep> \
  forge script script/FireComfortThrone.s.sol:FireComfortThrone \
  --rpc-url $RPC --broadcast --slow --gas-estimate-multiplier 200 -vvvv
```

### Optional sleeve (keep stables liquid + create idle)

Fund hot with Circle USDC, then:

```bash
KING_GO=1 FIRE=1 SLEEVE_USDC=250000000000 ...  # $250k example
```

### Monthly pay

```bash
cast send <KING_PAY> "pay(uint256,uint256)" 0 0 \
  --private-key $HOT_KEY --rpc-url $RPC
# second arg = max from king yRSS principal (0 = fees only)
```

King should `yrss.approve(KING_PAY, max)` once if using principal harvest.

---

## Freeze note

`NO-RECYCLE-UNTIL-EXIT.md` blocked old `FireSelfSeedNine`. Comfort throne is the **lift path**: fork-tested exit exists (Vault V2 forceDeallocate), and this stack adds keep/sleeve/pay. Live fire still needs explicit **`KING_GO=1`**.

---

## Done when

1. One Morpho seat (dust folded).  
2. Free RSS on hot = `RSS_KEEP`.  
3. yRSS ≈ borrow (+ sleeve).  
4. `CrownKingPay` is feeRecipient.  
5. kUSD / desk RSS untouched.  
6. King can call `pay` when idle/fees exist.
