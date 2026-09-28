# FREEZE — Three-Number NAV Dashboard

**Mode:** FREEZE → FIRE · public sovereign balance sheet  
**Doctrine:** ZK-attested only. **No capacity. No potential.** Auditable, not advertised.

---

## Plan fixes (handoff → chain truth)

| Handoff ask | Why it breaks / drifts | Refined deliverable |
|--|--|--|
| Wire live `CrownZkAttest` to *read* three rails | Live attest is immutable; only reads yRSS NAV + cold | **`CrownSovereignBoard`** snapshots 3 rails → root; **`commitPayrollRoot` + `attestLive`** binds root into live ZkAttest epoch |
| Ocean “~$6B gUSD / ~$11B depth” | Aero pool is **5B / 5B** on-chain | Publish **pool reserves** (chain), not thesis totals |
| Show America 100T capacity | Explicitly forbidden this fire | Board / dashboard **omit** capacity & unlocked |
| Silent public deploy | Gas on HOT is dust | Ship board+dashboard+tests; fire ZK root commit; board CREATE when ETH topped |

---

## Three rails × three numbers

1. **yRSS Gold** — locked gold (yRSS `totalAssets`) · idle real (Landing eUSD) · minted real (eUSD `totalSupply`)  
2. **Ocean** — eUSD in Aero pool · gUSD in Aero pool · depth = sum  
3. **Landing war chest** — idle eUSD · payrollOk (attest) · cold buffer bal  

Every number → Basescan / attest `payloadHash` proof link. Timestamped on publish.

---

## One-block

```
FREEZE=sovereign-nav-dash
NO=capacity · potential · press
YES=3rails×3nums · ZK-root · proof-links · silent
FIRE=board+dash+attest-commit
```
