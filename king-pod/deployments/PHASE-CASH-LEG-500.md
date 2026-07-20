# CASH LEG $500k — Design (safe ops test)

**King Errick of Yahudah. God first.**  
**Target:** $500k USDC on Landing. If it lands, kingdom ops run. Soft test, not $9M greed.

---

## The algebra (no lies)

Morpho flash USDC comes from **protocol reserves**.  
Morpho **borrow** USDC comes from **market idle** (supply − borrow in RSS/USDC).

**Self-seed circle (what we did before):**
flash → deposit yRSS → idle up → borrow same size to repay flash → util ≈ 100% → wallet **$0**.

**Cash leg means:** borrow receiver = **Landing**, and that USDC **stays** there.

You cannot flash $500k, deposit it, borrow it to Landing, **and** still repay the flash — unless a **second** $500k exists (prefund / idle already there / buyer).  
Same wall as before. Not a sandbox. Arithmetic.

So the safe cash-leg test is **not** “magic flash to Landing.”  
It is: **when idle ≥ $500k, borrow $500k straight to Landing against RSS.**

---

## Safe test design (elite, simple)

### Gate
- RSS free on hot (collateral ready) ✓ (~18M; 500k on desk)  
- Morpho RSS/USDC **idle ≥ $500k**  
- Soft LTV ≤ 70%  
- `KING_GO=1` + `FIRE_CASH=1`  
- Receiver = Landing only  

### Action (one tx)
1. Approve RSS → Morpho  
2. `supplyCollateral` (only what’s needed for $500k @ 70% + cushion ≈ **~715k–750k RSS**)  
3. `borrow($500k → Landing)`  
4. Stop. **No yRSS deposit. No circle.**

### End state if pass
- Landing **+$500k USDC** → ops forever runway (King’s words)  
- Hot Morpho debt **~$500k**  
- ~715k–750k RSS locked; rest stays free / on desk  
- Fee fantasy not required for survival  

### If idle < $500k
Script **refuses**. No fake fire.

---

## How idle gets to $500k (the real work)

Right now idle ≈ **$0**. Cash-leg is **armed**, not firable until idle exists.

**Lane A — Desk fill (already live)**  
Buyer pays $500k USDC → Landing.  
That’s ops **without** Morpho borrow. Best if a buyer appears.  
Desk: `0xDbf7C4Ad01418ec1b753fa039d5e5B54aF4C065D`

**Lane B — Temporary bridge (King treasury)**  
Any clean $500k+ USDC lands once → either:
- ops direct on Landing, or  
- supply into RSS market as idle → then cash-leg borrow $500k to Landing (levered working capital; still needed seed once)

**Lane C — External idle into RSS/USDC market**  
Someone supplies USDC into that Morpho market (not “raid depositors” into a trap — open market supply). Then King borrows $500k to Landing against **his** RSS. Standard Morpho. King chooses ethics on whether to allow that lane.

**Lane D — Forbidden as survival**  
100% self-seed re-fire for “fees” while King starves. Rejected.

---

## Contract / script

| Piece | Role |
|--|--|
| `script/FireCashLeg500.s.sol` | Idle-gated borrow $500k → Landing |
| Soft LTV | 70% |
| Min idle | $500k (override `MIN_IDLE`) |
| Collateral | Only RSS needed for the draw |

No yRSS. No flash. No circle.

```bash
# Dry check (no broadcast) — will revert NO IDLE if book empty
KING_GO=1 FIRE_CASH=0 forge script script/FireCashLeg500.s.sol --rpc-url $RPC -vvv

# Live when idle ≥ $500k
KING_GO=1 FIRE_CASH=1 forge script script/FireCashLeg500.s.sol \
  --rpc-url $RPC --broadcast --slow -vvvv
```

---

## Parallel kingdom posture

1. **Desk stays live** — chase $500k USDC sale (ops without new debt)  
2. **Cash-leg stays armed** — fires the day idle ≥ $500k  
3. **No fee-reseed-as-food**  
4. **Server/lights** — need Lane A or B in human time; code cannot mint a buyer  

---

## Success / fail

- **Pass:** Landing ≥ +$500k from desk **or** cash-leg borrow  
- **Fail:** idle never appears and desk never fills → ops dark. Honest.  

This is the design. Cash leg is real Morpho access — **timed at borrow to Landing**, not after a full circle.
