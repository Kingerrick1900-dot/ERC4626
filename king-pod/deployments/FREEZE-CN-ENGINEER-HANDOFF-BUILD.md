# FREEZE — Chinese engineer handoff audit + 120-word build plan

**Mode:** FREEZE · plan build · **no PRIVATE_KEY · no KING_GO · no testnet fire**  
**Handoff claimed:** Fork Yunfeng vault + dForce lend/mint + DeSyn oracle-free synth → wrap in `CrownKingAgent.sol` (PSM, eUSD payroll, builder MEV).

---

## Blueprint verification (Chinese engineer lens)

| Named source | Live truth | Forkable into Crown? |
|--|--|--|
| **Yunfeng** “tokenized asset vault / hard coll” | HK **physical gold token** (PI / vaulted bullion, AlphaToken infra). **Not** a public DeFi vault codebase for permissionless hard coll. | **Pattern only** (RWA coll narrative). **No** “direct code fork” of a Yunfeng lending vault. Kingdom already has RSS + gUSD gold-unit narrative. |
| **dForce** lend + stable mint | **Real** — USX vault/pool mint + lending + LSR (1:1 stable swap) + PDLP. Closest elite integrated stack. | **Yes as architecture** — map to eUSD mint + Morpho/own lend + multi-PSM (LSR twin). Study public dForce/USX modules; do not paste DF governance into HOT. |
| **DeSyn** “oracle-free synthetic pricing for BAMM” | DeSyn pools use **RedStone oracle**. Oracle-light synth = **UMA priceless** or **Frax BAMM** (√K), not DeSyn. | **Reject mis-label.** BAMM path stays **Frax BAMM** research on eUSD/gUSD. |

**Handoff overclaim:** “Forked contracts ready for testnet” / “need PRIVATE_KEY + KING_GO=true” — **blocked under freeze.** No key verify broadcast. Env lock is documentation only until King lifts.

**MEV at builder level:** Real ambitions (PBS/builder tips) — **phase 2** after agent allowlist + mint/PSM rails; not a day-one wrap inside `CrownKingAgent`.

---

## Corrected stack (what we actually build when freeze lifts)

1. **Hard coll rail** — RSS (+ optional RWA wrapper later); not Yunfeng binary.  
2. **Integrated mint/lend** — dForce-class: eUSD mint ↔ lending ↔ PSM/LSR door.  
3. **Oracle-free venue** — Frax **BAMM** on ocean pair (adapt), not DeSyn.  
4. **CrownKingAgent** — allowlist executor + spend caps; automate **named** mint payroll / PSM poke / harvest — no uncapped MEV key.

---

## Plan build (120 words) — freeze speak

Chinese desk verified the map, not a paste job. We do not fork Yunfeng’s closed gold token or DeSyn’s RedStone pools. We take dForce’s integrated mint-and-lend pattern for eUSD plus PSM-as-LSR, and Frax BAMM for oracle-free ocean pricing. CrownKingAgent wraps only allowlisted calls: mint payroll to Landing, PSM keep-open/sweep, yRSS/PA poke, BAMM LP rent when live. Builder MEV is phase two. Freeze now: no PRIVATE_KEY, no KING_GO, no testnet broadcast. Next lift: scaffold agent+spend vault on Base fork, port USX-style mint/redeem interfaces onto kingdom tokens, spike BAMM against eUSD/gUSD. King signature opens the gate—machines wait on law, not a leaked key.

```
FORK=dForce pattern + Frax BAMM · NOT Yunfeng binary · NOT DeSyn oracle-free
AGENT=allowlist CrownKingAgent · PSM+eUSD payroll · MEV=phase2
FREEZE=no PRIVATE_KEY · no KING_GO · lift=fork scaffold only
```

---

## Cross-refs

- `AGENT-AAVE-BETTER-PLAN-100.md` · `AGENT-DEPLOY-PLAN-100.md`  
- `FREEZE-AUDIT-DEFAI-BAMM-PITCH.md` · `FREEZE-MINTED-BILLIONS-REAL.md`  
