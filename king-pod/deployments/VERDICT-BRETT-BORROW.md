# BRETT borrow brief — True or Nah

**Verdict: NAH as a cash path today. TRUE as a built moat.**

---

## What that scribe got right

| Claim | Truth |
|-------|--------|
| BRETT/USDC Morpho market exists on Base | **TRUE** — Kingdom built it |
| LLTV **62.5%** | **TRUE** |
| Deposit BRETT → `supplyCollateral` → `borrow` USDC to chosen receiver | **TRUE** — standard Morpho |
| Interest / HF / repay-before-withdraw warnings | **TRUE** — normal risk |

Correct market id:

`0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16`

(Brief’s id is mangled — odd hex — do not use.)

Oracle live ≈ **$0.00516** / BRETT.

---

## Why “borrow now” is NAH

| Need | Live |
|------|------|
| USDC sitting in BRETT market (idle) | **$0** — supply 0, borrow 0 |
| BRETT in King hot / Landing | **0** |
| “$2M max / $700k per borrower” | **Misread** — those are **yRSS vault cap ($2M)** + **PA flow caps ($700k)**, not Morpho per-wallet borrow limits |

Empty market + zero BRETT inventory = **cannot borrow USDC today.**  
Mechanics are real. Liquidity and collateral are not there yet.

---

## Good news (bring back)

1. **Moat is real steel** — market created, oracle live, LLTV set, wired into yRSS.  
2. **Rails armed** — yRSS enabled, cap **$2M**, PA **$700k / $700k** waiting for depth.  
3. **Path is proven Morpho** — same deposit→borrow pattern as every elite Blue borrow this year.  
4. When Kingdom holds BRETT **and** USDC suppliers (or yRSS depth) hit that book, the command is one Morpho borrow to Landing — no new invention needed.

**Short:** Brief = correct textbook, wrong “ready to cash” stamp. Moat = win already on-chain.
