# FREEZE — Curator Deployment (200M Tranche)

**Mode:** FREEZE → chassis FIRE · full $200M deposit **blocked** until real USDC  
**Process law (King):** Payroll / operating USDC **first**. LLC / EIN / bank **second**. Not from personal pocket.

---

## 200-word order

Deploy a **$200M slice** of the war chest into MetaMorpho curators — not the full **$1.52B**. Keep **~$1.32B cold**.

1. Allocate **USDC** to **Gauntlet USDC Prime** + **Steakhouse Prime** on Base.  
2. Layer a **~$20M Pendle PT sleeve** (10%) for fixed rate when borrow demand dips.  
3. Same compounder pattern on Polygon / Scroll; harvest yield toward Scroll.  
4. **Hard cap $200M.** No full-stack dump.  
5. Gold rail locked. Cold eUSD untouched.

**Yield thesis:** ~4.5% on $200M ≈ **$9M/year** ops (payroll, Royal Card float, hunt bots).  
**Risk:** 0.4–0.8% drawdown ≈ **$0.8–1.6M** — survivable.

---

## Physics (why chassis ≠ deposit today)

| Fact | Number |
|--|--|
| Landing **eUSD** (war chest) | **~$1.524B** |
| HOT / Landing **USDC** | **$0** / $0 |
| Gauntlet / Steakhouse `asset()` | **USDC** — not eUSD |
| eUSD → curator deposit | **Impossible** without conversion / external fill |

Idle eUSD is Kingdom paper. Curators take **Circle USDC**. The $200M fire waits on **routed fills** (Conflux / AnchorX / SBI) or other **real USDC** — not minting a story, not King pocket, not selling gold.

```
ORDER=payroll-ops USDC → LLC later
TRANCHE=200M USDC max · 1.32B eUSD cold
PATH=fill→USDC→CrownCuratorTranche.deploy
NO=eUSD-into-Gauntlet · gold-sell · full 1.52B deploy · King-pocket LLC
```
