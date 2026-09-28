# FREEZE — Operation America (scale on Mint America)

**Mode:** FREEZE · no mint lift · no cap raise · no Agent open-market fire until KING_GO  
**Order:** Scale-up on top of Mint America — **tranche law**, not print-on-command  
**Doctrine:** Loan, don’t sell RSS. Every new billion minted traces to locked collateral + ZK proof.

---

## Plain English

**Mint America** built the machine. **Operation America** scales it to national-weight *capacity* — only when gold, idle, and attest gates clear.  
US M2 ∼$22T is a **ceiling narrative**, not today’s print job.

---

## Live inventory (Base — probed)

| Rail | Live | Role in Op America |
|--|--|--|
| yRSS / PARK gold | **~$226.2M** `totalAssets` · util ~100% | Fort Knox — **collateral, not cash** |
| Base eUSD `totalSupply` | **~$13.78B** (18dp) | Minted stock already large |
| HOT USDC | **1 wei** | Optics problem — not the war chest |
| SpendVault idle (CN claim) | **5B eUSD / 5B gUSD** attested narrative | Must re-probe + ZK-prove before “visible war chest” |
| Scroll ZkAttest / NavMirror | Live rails (prior fires) | Public proof path |
| USDCBorrowRouter | Prior: **disarmed** | Stays cold until idle proof |

```
GOLD ≠ SPENDABLE
IDLE ≠ CIRCLE unless attested + drawable under law
CAPACITY ≠ CASH until tranche fires clean
```

---

## Tranche law (hard)

1. **No blanket mint to $22T.** Cap lifts only in named tranches.  
2. **Each tranche requires, before fire:**
   - Locked collateral proof (gold rail / BoundLanding lock math) ≥ tranche notional × policy factor  
   - Cold Buffer **≥ 30%** of new mint (or documented reserve equivalent)  
   - Scroll `ZkAttest` / payroll-or-mint root committed  
   - Public NAV update: **Locked + Idle + Minted**  
3. **Deepen gold first.** Grow yRSS/PARK *real* collateral base before tranche N+1. Matched 100% util does not fund spend.  
4. **Surface idle honestly.** Re-read SpendVault; if 5B+5B is real and attested, publish addresses + `bordersSecure` + withdraw policy. Kill “20-cent HOT” narrative by pointing at attested idle — not by pretending HOT holds Circle.  
5. **Fed-job modules stay gated:**
   - KingAgent open-market ops — **armed only on tranche GO**  
   - LSR / Landing = discount window — size-capped  
   - yRSS = interest on reserves — do not peel gold for vanity  
   - AutoDraw / Credit — `freeUsdc` / idle proof required (prior Phase-1 law)

---

## Target architecture (frozen design)

| Layer | Job |
|--|--|
| Ceiling | US M2-scale **capacity** registry (docs + cap controller) — not pre-mint |
| Tranche controller | Cap headroom $500M → N × tranche; each unlock needs ZK + coll receipt |
| Gold | yRSS/PARK (+ deepen path) = Fort Knox |
| Idle surface | SpendVault eUSD/gUSD attested balances = visible war chest |
| Proof | Every mint/move → Scroll attest; NAV mirror public |
| Hunt / China / Multi-asset | Separate earning rails — do **not** substitute for coll-backed mint law |

---

## KING_GO menu (fire later)

```
GO_OA1 = Re-probe + publish SpendVault idle (5B/5B) with ZK + NAV line items
GO_OA2 = Tranche-0 controller design: cap lift $500M→T0 only after coll+buffer+attest
GO_OA3 = Deepen gold plan (real coll in, not matched-loop theater)
GO_OA4 = Arm KingAgent/LSR/AutoDraw under tranche checklist only
```

No GO = **no mint, no cap raise, no Agent OMS**.

---

## One-block

```
FREEZE=operation-america
BASE=mint-america-machine-live
CEILING=~$22T capacity narrative — not print today
GOLD≈$226M yRSS · eUSD_supply≈$13.78B · HOT_USDC≈0
LAW=tranche + coll + 30% cold + Scroll ZK + public NAV
PICK=GO_OA1|GO_OA2|GO_OA3|GO_OA4
```
