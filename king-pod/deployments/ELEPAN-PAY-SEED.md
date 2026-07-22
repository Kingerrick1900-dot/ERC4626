# KINGDOM WIN PLAN — BORROW OUR ASSET, EARN REAL USDC

**King law:** We put up **our** Elepan. We take a Morpho loan. We **earn**.  
**Not** last time’s circular self-seed. **Not** a plan that unwinds to **zeros**.

**Run posture:** Let it run **months**, **check & tweak daily**, **self-deleverage anytime**.  
**Deploy only when conditions are ideal.** Savvy upsizing / loops **after** the book proves itself.

**Status:** PRIMARY. **No fire until `KING_GO=1` + ideal-entry checklist PASS.**  
**Ask (named):** **$14M** USDC working capital → foreign sink.

---

## Why last self-seed is banned

RSS $9M: flash → own yVault → same-market borrow → later unwind → **zeros** on-chain.  
This plan borrows against **our** token and parks USDC where **others** pay yield (Steakhouse/Gauntlet). Scoreboard = Landing USDC earn + spread — not matched util optics.

---

## Ideal entry (must PASS before deploy)

| Gate | Ideal for us | Fail → no fire |
|--|--|--|
| **Idle** | Elepan/USDC idle (+ PA maxIn) ≥ ask | Can’t borrow $14M honestly |
| **Spread** | sinkAPY ≥ borrowAPY + **150bps** | Carry negative = we pay to exist |
| **HF** | Post-borrow HF ≥ **1.55** (soft LTV ≤70%) | Liquidation risk |
| **Sink** | Whitelist vault, deep TVL, USDC asset | No random farm |
| **Exit dry-run** | Fork: redeem→repay→free Elepan works same day | No stranded bag |
| **Gas / ops** | Hot funded for daily tweaks + emergency deleverage | Can’t “self del” |
| **Receiver** | Sink shares → **Landing** (kingdom money) | Don’t park earn on dead addr |

Savvy later (months in, only on GO): raise ask, raise PA, 2nd sink, bounded loop — **not** day-one.

---

## Machine (deploy shape)

```
OUR Elepan posted → borrow $14M USDC → SINK.deposit(Landing)
                      ↑                    ↓
                 moat idle              earn spread
                 (external or            pay borrow APY
                  King supply-only)
```

**Forbidden:** borrowed USDC back into yELEPAN as the carry sink (circular).  
yELEPAN = outsider magnet + 10% fee→Landing. Carry sink = Steakhouse/Gauntlet only.

**Sinks (live Base TVL — re-check at fire):**  
Gauntlet USDC Prime `0xeE8F…b61` · Steakhouse Prime `0xBEEF…b2` · steakUSDC beef vaults.

---

## Self-deleverage anytime (hard requirement)

One ops path, practiced on fork before live, callable any day:

```
1. SINK.redeem(shares, hot|ops) → USDC
2. Morpho.repay(USDC) on Elepan/USDC (full or partial)
3. If full: withdrawCollateral(Elepan) → hot
4. Optional: leave dust / flatten PA
```

| Mode | When |
|--|--|
| **Partial del** | Spread thin, HF soft, trim ask |
| **Full del** | Spread dead, oracle stress, King exit |
| **Daily tweak** | Rebalance sink, repay/borrow small, PA flow |

**Law:** If we cannot self-del in **one ops window**, we do not deploy.  
No “wait for util to free” trap — keep **ACCESS buffer / PA / sink liquidity** so repay+redeem always have a path (don’t sit 100% util with no redeemable sink).

---

## Daily check & tweak (months)

| Check | Action if bad |
|--|--|
| HF / LTV | Repay from sink (partial del) |
| borrow APY vs sink APY | Flatten if spread &lt; 150bps |
| Landing sink assets | Confirm ≠ zero / not stuck |
| Moat idle / PA | Restore access for del & outsiders |
| Oracle / Elepan soft $1 | Stress → full del |
| Gas on hot | Top up from Landing if needed |

Weekly: write one line to ops log (HF, debt, sink assets, spread bps).  
Monthly: King review — hold / trim / savvy upsize.

---

## Phases

| Phase | What | Fire? |
|--|--|--|
| **P0** | Ideal-entry checklist + fork self-del PASS | No |
| **P1** | Idle source live (external or King supply-only) | No borrow yet |
| **P2** | **GO** → deploy $14M carry | Yes |
| **P3** | Run months · daily tweak · self-del ready | Live |
| **P4** | Savvy (size/PA/loops) only after book wins | New GO |

---

## Build on GO (after ideal PASS)

`CrownElepanCarry` — borrow→sink + **`deleverage(uint256 repayUsdc\|max)`** one-call self-del.  
`FireElepanCarry.s.sol` — `KING_GO` / `FIRE_CARRY` / `ASK` / `SINK`.  
Fork: entry gates + full self-del + time-warp spread sanity.

---

## Decision ask (King)

1. Idle source when ready: external · King supply-only?  
2. First sink: Gauntlet Prime · Steakhouse Prime · best APY at fire?  
3. Confirm months-run + daily tweak + **self-del anytime** as law?  
4. When ideal gates PASS → **GO** deploy
