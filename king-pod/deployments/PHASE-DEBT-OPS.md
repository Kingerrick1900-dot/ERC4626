# Kingdom Debt Free + Ops ($500k set)

**Serve God. Steward the nation. Own capital only. No raiding.**

---

## What the King built

- RSS is a **working asset**, not a public trading meme.
- Morpho lent **$9M** against that asset — real recognition of the book.
- Fortress (self-seed) funded the protocol. Loan is a real kingdom obligation.
- Ops needs a **$500k set** (tools, server, King welfare, scribes). Not greed for $9M pocket cash.

---

## Two jobs (do not mix them in your head)

| Job | Meaning |
|-----|---------|
| **1. Pay the Morpho loan** | Clear / dust the self-seed debt; free RSS back to hot |
| **2. Ops USDC $500k** | Convert a slice of freed **asset power** into spendable USDC |

Lighter RSS is **correct** when it pays debt / funds the nation. That is the asset’s purpose.

---

## Step A — Debt free (on-chain, ready)

**Proven contract:** `CrownChunkFreeRss` (already live-proven once on Base historically).

**Script:** `script/FireKingdomDebtFree.s.sol`

```bash
# Prep
KING_GO=1 FIRE_FREE=0 forge script script/FireKingdomDebtFree.s.sol \
  --rpc-url $RPC --broadcast --slow

# Fire — pay debt, free RSS to hot, sweep leftover yRSS dust to Landing
KING_GO=1 FIRE_FREE=1 SWEEP_LANDING=1 FREER=<from prep> \
  forge script script/FireKingdomDebtFree.s.sol \
  --rpc-url $RPC --broadcast --slow --gas-estimate-multiplier 200
```

**What it does (atomic chunks):**
1. Flash USDC  
2. Repay Morpho debt (down to ~$300 dust)  
3. Pull from **King’s yRSS** to repay flash (own claim)  
4. Withdraw freed RSS collateral → **hot**  
5. Optional: sweep leftover yRSS redeem → **Landing**

**End state target:**
- Morpho debt ≈ dust  
- ~18.5M RSS on hot (working asset free)  
- yRSS loop unwound  
- **No depositor funds touched**

---

## Step B — Ops $500k USDC (honest field)

**Live fact:** Base has **no** UniV3/Aerodrome RSS/USDC (or RSS/WETH) pool right now.

Morpho’s **$1 FixedOracle** valued the loan. That is **not** the same as a DEX bid for $500k.

So after Step A, the King holds the asset. Ops USDC requires a **conversion venue**:

1. **OTC** — sell ~500k RSS (oracle notion) to a known buyer for USDC → Landing  
2. **Seed a pool** — King places a thin RSS/USDC pool when a clean USDC bridge exists, then sell sized amount  
3. **Do not** pretend `withdraw` on yRSS pays $500k while the loop is fully drawn  

Step A still **must** run first if the goal is to pay off the Morpho loan and restore the asset to hot.

---

## Ethics

- Own-token loan / own yRSS claim only  
- No borrowing against other people’s deposits  
- No Gauntlet/partner “please fund us” as the plan  
- King GO on every broadcast  

---

## Order of battle

1. Fork-sim `FireKingdomDebtFree` (FIRE_FREE=1) — confirm debt→dust, RSS→hot  
2. King GO live Step A  
3. Kingdom books: record freed RSS  
4. Step B: OTC/pool for **$500k ops set** only  
5. Steward remaining RSS as sovereign asset (not meme float)

---

## Related

- Phase 1 fortress: `PHASE-1-RESTORE.md` (how we got here)  
- Prior free: `CHUNK-FREE-LIVE.md`  
- Contract: `src/CrownChunkFreeRss.sol`
