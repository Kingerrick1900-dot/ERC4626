# Why moving $1,000 needs (or does not need) multi-flash machinery

**Verdict for King:** Do **not** run a 2×/3× Morpho-flash “atomic strike” live until this is accepted.

The honest answer to *“Why does moving $1,000 need three flash loans?”* is:

> **It should not.** Multi-flash plumbing is a symptom of trying to do three incompatible jobs in one Morpho flash on an empty self-seeded market. The self-seed structure does **not** inherently require that machinery — it requires accepting what self-seed actually produces.

---

## What self-seed actually produces

Self-seed (ATTACK) on Morpho Blue with **no outside suppliers**:

1. Flash (or otherwise obtain) $X USDC  
2. Deposit $X into Vault V2 → adapter supplies Morpho  
3. Borrow $X against RSS → repay the flash  

**End state:** vault shares ≈ $X, Morpho debt = $X, RSS posted.  
**Not produced:** spendable USDC in a wallet.

That is circular by design. Access (can you unwind?) ≠ outside capital.

Live market today (RSS/USDC):

| Field | Value |
|-------|--------|
| `totalSupplyAssets` | ~$1.00 |
| `totalBorrowAssets` | $0 |
| Hot Morpho position | 0 / 0 / 0 |
| Hot liquid USDC | ~$0.10 |
| Landing USDC | $1 (prior dust) |

There is **no external Morpho liquidity** in this market. Any borrow you take must be funded by supply you just put in.

---

## Why “atomic attack + feed in one Morpho flash” breaks

Desired one-tx story:

`flash → post RSS → vault deposit → borrow → forceDeallocate → USDC to landing → repay flash`

Morpho withdraw liquidity is **market-local**:

```text
withdrawable = min(supply − borrow, Morpho’s USDC balance)
```

On a self-seeded market after deposit+$X and borrow+$X:

```text
supply − borrow ≈ 0
```

So you **cannot** pull the matching supply back out while the matching borrow stays open — unless you add temporary “IKR” supply, then try to pull that too, which hits the same wall.

| Pattern | What happens |
|---------|----------------|
| Flash 2×, supply IKR, forceDeallocate, withdraw IKR, **leave debt open** | IKR withdraw hits `insufficient liquidity` (sim failure we already hit) |
| Flash 2×, same path, **repay debt before IKR withdraw** | Works (live exit proof `0x88b2badd…`) — but then **no open loan / no extract** |
| Fork IKR exit with **real USDC left as Morpho supply** | Landing gets USDC; freer keeps Morpho supply — needs working capital, not a free flash |

So the 2×/3× flash designs are attempts to paper over that accounting identity. They are fragile because they fight Morpho’s liquidity rule, not because $1k is “hard.”

The live-proven path (`CrownLiveExitTest`) only closed cleanly by **repaying the borrow before withdrawing IKR**. That proves **access**, not **extractable funding**.

---

## Simpler sequences (honest)

### A — ATTACK only (simple, already designed)

`CrownSelfSeedV2`: flash **1×** → post RSS → vault deposit → borrow → repay flash.

- Complexity: one flash, one purpose  
- Result: shares + debt  
- Landing: unchanged  
- Use: prove ladder ATTACK end-state on Basescan before any FEED talk  

### B — FEED with real IKR working capital (simple, matches fork tests)

After ATTACK, to move vault USDC to cold landing at ~100% util:

1. Temporarily set penalty 0 (then restore 1%)  
2. Supply $X USDC to Morpho as IKR (real capital, **left in place**)  
3. `forceDeallocate` + `withdraw` to landing  

- Complexity: **zero flash required** for the economic move  
- Cost: $X USDC stays as Morpho supply (equity roughly conserved: landing + IKR − debt)  
- Hot today does **not** hold $1k USDC — so this path needs a real USDC source first  

### C — Do not combine A+B inside one Morpho flash

That combination is what spawned 2×/3× flash prototypes. It is the fragile plumbing. Reject it for $1k and for $9M until external market liquidity exists or King accepts B’s working-capital model.

---

## Direct answers

**Q: Why does moving $1,000 need three flash loans?**  
**A: It doesn’t.** If a design needs three Morpho flashes to move $1k to cold, the design is wrong for this market state.

**Q: Is there a simpler sequence?**  
**A: Yes.** ATTACK = one flash (or none if you already have USDC). FEED = IKR with real USDC left supplied, or wait for outside Morpho suppliers so normal withdraw/liquidity exists.

**Q: Does self-seed inherently require this complexity?**  
**A: No.** Self-seed inherently produces **shares + debt**, not wallet USDC. The complexity appears only when we demand “debt stays open **and** dollars appear on cold **and** Morpho flash repays itself on an empty market” in one transaction. That triple demand is what is fragile — not the $9M size.

---

## Gate before any live $1k / $50k / $9M

1. King accepts: self-seed ≠ spendable dollars.  
2. Choose path A (ATTACK only) and/or B (FEED with real IKR capital).  
3. Do **not** broadcast multi-flash atomic strike until a fork sim shows Morpho market `supply − borrow` after every step, with debt left open, and IKR withdraw not required to repay flash.  
4. Scale size only after the **chosen simple path** is live-clean — same plumbing, larger number — not after inventing more flashes.

**Status:** Live $1k atomic multi-flash strike is **HOLD**. Next action is King pick: micro ATTACK only, or fund IKR working capital for FEED.
