# FREEZE — CN Desk PSM Fill (atomic · real)

**Mode:** FREEZE · no builds yet  
**Tone:** Engineer playbook — join the desks that already opened the door, don’t talk past them.

---

## 120 words (refined)

Other engineers already named the real door: **Maker PSM / GSM**. Kingdom has it live — Base multi-PSM `0xF733…`, LitePSM / PowerRail ingest, GO-B Morpho→PSM seed. USDC in PSM is **$0** because no bot is hitting `sellGem`. That is the job.

**CN executes the fill, not the sermon.**

1. **Flash PSM arb (Maker):** Flash-borrow USDT/USDC → `sellGem` into multi-PSM → mint eUSD → buy flash asset on Aero/Curve → repay. When eUSD \< \$1 on the DEX, this **leaves real USDC in the PSM** and pays for itself in one tx. Same pattern elites used on DAI.

2. **Collateral mint when eUSD \> \$1:** Mint eUSD vs posted USDT/USDC (or GO-B: loan WETH vs RSS → borrow USDC → `seed` PSM). Spread + inventory, not hope.

3. **Cold / yield later:** Only after gem sits in PSM — DN yield tops cold; it does not replace the first USDC atom.

**Next build:** `CrownPSMFiller` — Aave/Morpho flash · USDT+USDC gems · fork-prove positive PSM USDC delta · arm KingAgent. AxCNH when gem listed. Align with FOUR-LIVE-AVENUES / GO-B / elite ingress — CN is the **atomic closer**.

---

## Join, don’t contradict

| Desk already proved | CN filler role |
|--|--|
| Elite ingress = PSM door | Bot that `sellGem`s when spread prints |
| GO-B WETH→USDC→PSM seed | Alternate fuel when WETH desk funded |
| LitePSM / 7683 / Completer | Sibling inbound rails — filler is DEX/flash leg |
| Ocean 5B/5B live | Exit/entry venue for the arb leg |

---

## Gates

| GO | Fork: PSM USDC ↑, flash repaid, Landing/HOT can sweep gem |
| KILL | Tx needs mint-eUSD-as-Circle with no `sellGem` and no USDC in |
| ARM | KingAgent + HOT after green fork numbers |

```
FREEZE=cn-psm-atomic-fill
DOOR=multi-PSM 0xF733… · LitePSM · GO-B
MOVE=flash sellGem arb · premium mint · then cold
BUILD=CrownPSMFiller (next) · fork-first
```
