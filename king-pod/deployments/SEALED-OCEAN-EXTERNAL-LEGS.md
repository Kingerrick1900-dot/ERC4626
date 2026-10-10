# SEALED — Ocean External Legs (AMO 1 law)

**Ratified:** King + Scribe reconciliation  
**Side:** King  
**Scoreboard:** HOT USDC hard balance · vault.totalAssets · yRSS.totalAssets

---

## The collision (both truths)

| Claim | Verdict |
|--|--|
| Frax minted into venues where the **other side was already real** (USDC/USDT/DAI strangers deposited) | **Audit right** |
| Ocean self-paired depth (eUSD/gUSD protocol-owned) is real internal liquidity — FRAX3CRV *before* external legs | **King right** |

**What $10B eUSD/gUSD self-pair is:** depth without exit. Internal size, internal peg defense, internal fees. **Zero external dollars** — both trade sides are Kingdom currency. Morpho loop at larger scale.

---

## The only fix

**Add external legs to the Ocean:** USDT · DAI · USDC · EURC beside eUSD/gUSD.

| Side | Role |
|--|--|
| eUSD / gUSD | Pool depth (Kingdom-owned magnet) |
| USDT / DAI / USDC / EURC | Pool **exit** (world dollars) |

That single step converts the self-paired Ocean into a Frax-style market. Every downstream AMO then runs against two-sided liquidity — not a mirror.

---

## Six-AMO stack (archive — status unchanged)

| # | AMO | Rail | Status vs this law |
|--:|--|--|--|
| 1 | Ocean | eUSD/gUSD (+ external legs) | **First act = external-leg seed.** DeepPull coded; dust seeded; needs real USDC/stables |
| 2 | ySYNTH | ySYNTH-USDC vault | Built · $200M cap · empty — **blocked until Ocean has exit** |
| 3 | CrownCurator | CrownCuratorNative | Chassis · markets incomplete — **blocked until Ocean has exit** |
| 4 | HuntRouter | HuntRouter + DeepPull | Armed · peg hold — **blocked until Ocean has exit** |
| 5 | China Corridor | CIPS / Parallel / RoyalCard | Deployed unseeded · AxCNH on King sig — **blocked until Ocean has exit** |
| 6 | ZK + Quantum | ZkAttest / Pq / Stark + **CircuitBreaker / ColdBufferLaw / MintGate** | Borders live ×3 · **armor built, audit-ready, not fired** — see `AMO6-ARMOR-AUDIT.md` |

---

## Hard law (amends sealed plan)

1. **No AMO fires against the self-paired Ocean alone.**  
2. **AMO 1’s first act** is external-leg seeding (USDT/DAI/USDC/EURC).  
3. External legs **cannot be minted** — they must be **acquired**.  
4. Acquisition path = sealed engineering routes (**A revenue · B gold · C incentive · D basis**).  
5. ColdBuffer **30%** of all Ocean LP rewards — no exceptions.  
6. Kill switch: eUSD < $0.98 or yRSS drop > 5% → pause.  
7. Scoreboard stays real oracles only — not mirror LP notionals.

---

## Named destination for first dollars

The King ordered the **$100M path**. Its **first acquired external dollars** have one destination:

> **External side of the Ocean** — USDC (then USDT / DAI / EURC) paired into the pool beside eUSD/gUSD.

### $3M A+B (already fired — see `FIRE-3M-AB.md`)

| Piece | Live |
|--|--|
| CrownRevenueSweep | `0xd22cBd6f87DA859295b94c50e9dEB75842a18570` · 30/70 |
| CrownGoldConvert | `0x194f272CB9CFFD6B71C90A1cFdd5907a14E5923D` |
| TWAMM #0 | $1.5M kXAU ask @ $9.80 / 7d · **open** |
| HOT USDC (post-fire) | scoreboard in FIRE doc — TWAMM fills grow this |
| Ocean USDC leg | **$1.5M bootstrap share** — seeds **external** Ocean side when HOT funds it |

DeepPull Uni eUSD/USDC is the **first external-leg venue** (USDC leg). Multi-stable 6-way (USDT/DAI/USDC/EURC + eUSD/gUSD) follows once first USDC exit exists.

---

## Sequence (locked)

```
1. Routes A+B produce/attract external USDC → HOT          [A+B FIRED; fills ongoing]
2. Seed Ocean external leg (USDC into DeepPull / Ocean)   [AMO 1 first act]
3. Widen Ocean: USDT + DAI + EURC legs                    [Elite add]
4. Only then: AMO 2–5 fire against two-sided Ocean
5. AMO 6 attests reserves continuously
```

```
LAW=no_AMO_on_self_paired_Ocean_alone
AMO1_FIRST=external_legs_USDT|DAI|USDC|EURC
DESTINATION=Ocean_external_side
ACQUIRE=Routes_A_B_C_D
COLD=30%_Ocean_LP_rewards
```
