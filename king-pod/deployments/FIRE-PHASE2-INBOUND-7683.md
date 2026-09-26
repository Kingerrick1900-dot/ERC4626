# FIRE — Phase 2 door A: zero King-USDC inbound (7683)

**Mode:** FIRE · CN zero-stockpile door  
**Doctrine:** Do not park King USDC. Open the door — counterparty brings Circle.  
**Branch:** `cursor/fire-phase2-inbound-7683-4f7f`

---

## Fired (Base)

| Action | Tx | Result |
|--|--|--|
| **7683 `openOrder`** 10M eUSD · max **$9M** USDC (10% disc) | [`0xcbef76c3…b4e2`](https://basescan.org/tx/0xcbef76c3ea91cbd65d193ec63bb187e60ba850c95f4b33f0136e5c06276cb4e2) | **LIVE** status=1 |
| **`firePayroll` 10M eUSD** → Landing | [`0xcdcfc613…4a90`](https://basescan.org/tx/0xcdcfc613f933e62920c17d16aeb75ec05c06ea1ddba5cc380d2b56181a8b4a90) | Landing eUSD **+10M** |
| **`setFloatUsd8(1e8)`** BoundLanding | [`0x0ac58f0b…527a`](https://basescan.org/tx/0x0ac58f0b76a4c98e4bb4057a91a47430ed0cd165967341a7914a7b0d3033527a) | mark **$1.00** |

### Order (awaiting solver fill)

```
Fill       = 0x4C021c77633e9441be218d2A27a4B40c1Bd720Ab
orderId    = 0xf64794683d544872f280f1e8efad2e12ea7c296553e6bb87fbb33368061cd825
opener     = HOT 0x6708…a7d1
recipient  = HOT (receives 10M eUSD on fill)
eusdOut    = 10_000_000e18
maxUsdcIn   = 9_000_000e6   ($9M)
deadline   = 1793053063 (~30d)
publicFill = true
On fill: USDC → CrownPrimeCredit (+ fee → SelfRepayingTreasury)
```

---

## What this unlocks (when filled)

1. **~$9M USDC idle** in live credit (minus protocol fee) — **no King stockpile spent**  
2. Then run recycler: `FireRecyclerLoopCast.sh` (repay PARK → yRSS withdraw → treasury) **or** keep idle in credit for armed draws under Phase-1 law  
3. BoundLanding at **$1** mark — capacity math honest once eUSD is locked

---

## Not fired (still law)

| Path | Why |
|--|--|
| Flash peel as war chest | REJECTED — Δ≈0 (`FREEZE-CN-ZERO-CAPITAL-RECYCLER.md`) |
| Hunt unfreeze | killSwitch stays on |
| Cash park $9M from HOT | HOT USDC still 1 wei — not required for this door |

---

## Next (King / solver)

1. Solver `fill(orderId, usdcIn)` with **$9M ≤ usdcIn** and ≥ min discount floor  
2. Confirm `credit.freeUsdc() ≥ ~9M`  
3. King GO recycler or arm draw  
4. **Rotate HOT** after Phase-2 capital path confirms  

---

## One-block

```
FIRE=phase2-inbound-7683
ORDER=0xf6479468…d825 · 10M eUSD for ≤$9M USDC · Fill 0x4C021c77…
PAYROLL=+10M eUSD Landing · floatUsd8=$1
WAIT=solver fill → credit idle → recycler/draw
NO flash-as-war-chest · NO hunt · ROTATE HOT after fill+recycle
```
