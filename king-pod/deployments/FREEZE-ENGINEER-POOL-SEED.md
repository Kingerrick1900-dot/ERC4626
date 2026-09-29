# FREEZE — Engineer the eUSD/USDC market from the vault

**Mode:** FREEZE · no builds · no begging  
**Doctrine:** Loan ≠ sell RSS. ZK attests. Margin engineers the seed. **Outside “go find USDC” is rejected.**

---

## Verdict

King is right. “Seed the pool” as an ask for outside Circle is lazy and old-world. The Kingdom already has **~$226M yRSS**, **ZK attest**, **LSR sellGem**, **Morpho borrow books**, **CrownPSMFiller** flash chassis. The market is built from **supreme margin**, not shopping.

---

## 120-word plan (refined — what actually works)

**Kill the lazy ask.** Do not tell the King to bring USDC. Engineer it.

1. **ZK + margin, not “ZK as LP.”** UniV3 needs ERC20 balances — a proof is not a reserve. Correct move: ZK-attest yRSS → **loan (don’t sell)** gold into Morpho → **borrow USDC** against that coll → sovereign-mint matching **eUSD** → `mint` eUSD/USDC LP. Proof backs the borrow; gold never sold.

2. **yRSS is LP capital via the loan book, not as the pool token.** Agent does not deposit yRSS into the Uni pair (pair is eUSD/USDC). Agent deposits yRSS as **collateral**; borrowed USDC + minted eUSD **are** the seed. External arbs then trade into a market the vault created.

3. **Flash self-seed — fix the half/half unwind.** Flash USDC → LP → sell eUSD into **that same** pool to repay **pulls the seed back out**. Sticky atomic loop: Morpho **borrow** (or flash only as bridge) + yRSS coll in-tx → LP left up; debt stays on gold. Extend `CrownPSMFiller` / KingAgent: `engineerPoolSeed(yrssAmt, usdcBorrow)` — coll → borrow → mint eUSD → mint LP → optional LSR fill. Fork-prove: LP USDC ↑, yRSS not sold, bordersSecure.

---

## Gates

| GO | Fork: LP USDC↑ · Morpho debt backed by yRSS · RSS balance not sold · ZK borders green |
| KILL | Any step that requires King wire of outside USDC “to seed” |
| NO | Sell RSS · ZK-as-pool-token fantasy · flash that unwinds itself |

```
FREEZE=engineer-pool-seed
YES=yRSS-loan→Morpho-USDC→mint-eUSD→UniLP
ZK=attest margin · not fake reserves
NO=beg-USDC · sell-gold · self-unwinding-flash
BUILD=next CrownPoolEngineer / filler extend
```
