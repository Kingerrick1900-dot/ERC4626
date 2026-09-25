# FREEZE — CN desk refine: bootstrap · shield · exit (elephant awake)

**Mode:** FREEZE · plan only · **no txs · no mixer build · no KING_GO**  
**Tone:** War plan completed — not a weak note. Scribe’s three gaps are **accepted**. Two are built into law; one is **reframed** so the kingdom does not become a sanctions-evasion lab.

**Live stack already on Base (do not re-litigate):**  
Agent `0x128d…f6bA` · LSR `0x3ede…da4F` · BAMM `0xAb21…c3B2` · SpendVault `0xc3f2…2458` · Landing ≈ **1.5B eUSD** · Morpho eUSD idle ≈ **145M** · HOT ETH ≈ **dust ($0.001)**.

---

## Verdict on the Scribe

| Gap | Scribe ask | CN desk law |
|--|--|--|
| **1 Bootstrap / gas ceiling** | Spark plug before ZK/MEV/PSM | **ACCEPT — mandatory Step 0** |
| **2 Jurisdiction shield** | ZK mixer so Circle/Tether cannot freeze USDC | **REJECT mixer-as-blacklist-defeat.** **ACCEPT sovereign shield** = reduce issuer dependency + rail diversification + wallet segregation |
| **3 Exit / redemption** | Buffer + always-on eUSD→USDC out | **ACCEPT — mandatory LSR law + cold buffer** |

Fortress without a gate loses the peace. Fortress that only exists to defeat issuer freezes loses legitimacy. We build a **gate**, a **spark**, and a **shield that is sovereignty — not laundering theater**.

---

## 1) Bootstrap — Execution layer (gas ceiling)

**Fact:** Base gas is **cents**, not millions. HOT fails because it has **no spark**, not because fees are elite-expensive.

### Law
```
NO ZK proof batch · NO agent poke · NO PSM harvest · NO BAMM seed
UNTIL HOT_ETH ≥ BOOTSTRAP_FLOOR
```

| Param | Value |
|--|--|
| **BOOTSTRAP_FLOOR** | **0.02 ETH** on HOT (~$50–80) — covers L1 data-fee buffer + 50–100 agent/LSR calls |
| **OPS_FLOOR** | **0.005 ETH** — pause non-critical fires if HOT falls below |
| **GAS_CEILING** | Refuse any single tx if quoted **> 0.002 ETH** on Base (bug / wrong chain) |

### Spark sources (ordered — pick one, freeze until named)
1. **King personal / treasury ETH** → HOT (fastest · honest).  
2. **Landing ETH** (~0.00014 already there) + top-up — needs Landing key or transfer path.  
3. **Swap dust kingdom assets for ETH** only if King names size (keep eUSD core).  
4. **Micro ETH loan / friend wire** — optional; not Morpho theater.

### First-hour sequence (after spark)
1. Confirm `HOT_ETH ≥ 0.02`.  
2. `CrownKingAgent.firePayroll` smoke (1M eUSD) — proves LSR+minter.  
3. `observe()` + SpendVault pause test.  
4. Only then ZK / MEV / ocean scale.

**CN note:** Elephant awake ≠ burn the wallet on vanity deploys. Ceiling is discipline.

---

## 2) Jurisdiction shield — sovereignty, not blacklist theater

### What we will **not** build (freeze kill)
- **ZK mixer / tumbler whose purpose is to defeat Circle or Tether freezes / sanctions routing.**  
  That is not “elite DeFi.” That is a crime-adjacent product. CN desk refuses it in this kingdom plan.

### What we **will** build as the real shield (Maker/dForce/Sky pattern)

| Layer | Mechanism | Why it beats issuer freeze risk |
|--|--|--|
| **A — Settlement currency** | Kingdom ops, payroll, bonds settle in **eUSD** by default | Enemy cannot freeze what they did not issue |
| **B — Multi-rail ingress** | LSR/PSM accepts **USDC + EURC + DAI** (and later USDT only if King insists) into **segregated** reserve buckets | One issuer blacklist ≠ kill all blood |
| **C — Wallet segregation** | `HOT` (ops) · `Landing` (payroll) · `PSM_HOT` (active LSR) · `PSM_COLD` (redemption buffer) · `TREASURY` | Blast radius limited; rotate HOT after paste |
| **D — Receive hygiene** | Fresh receive addresses per counterparty desk; no single public “Kingdom USDC dump” forever | Ops privacy without a mixer |
| **E — Legal / venue** | If King wants jurisdiction shield: named entity + banking rails in a friendly venue — **off-chain counsel**, not a Solidity loophole | Real immunity is institutional |

### Stealth / ZK — allowed only as
- **Proof of reserves / payroll attestation** (already in kingdom ZK gates).  
- **Private counterparty RFQ** (amounts/identity), settle on-chain in clear to LSR.  

**Not allowed:** “route USDC so Circle cannot freeze.” If Circle freezes a hot receive address, **cut to eUSD rails and alternate gems** — do not race their compliance engine with a mixer.

**One line:** Sovereignty = **own the unit of account**. Parasite survival = hide inside theirs.

---

## 3) Exit ramp — redemption path + bank-run buffer

### Law (bind into `CrownLsrEusd` on next lift)
```
buyGem (eUSD → USDC) MUST stay live while reserves > 0
REDRAW from yield engine FORBIDDEN for buffer tranche
```

| Bucket | % of captured USDC | Home | Purpose |
|--|--|--|
| **COLD_REDEEM** | **≥ 30%** | `PSM_COLD` / LSR locked buffer | Instant / same-day `buyGem` |
| **HOT_PSM** | **≤ 40%** | LSR active | sellGem / arb / keep-open |
| **YIELD** | **≤ 30%** | Morpho / BAMM / approved only | Earn — **liquidatable back to COLD in ≤ 24h** |

### Redemption SLA
| Size | Promise |
|--|--|
| ≤ **$100k** / day / address | Same-block `buyGem` if COLD+HOT cover |
| ≤ **$1M** | ≤ 24h from YIELD unwind |
| Bank-run | Pause **mintPayroll** + **sellGem** first; **never** pause `buyGem` while USDC remains |

### Live code map
- `CrownLsrEusd.buyGem` / `sellGem` / `keepOpenSweep` / `usdcReserves` — **already live**.  
- Next lift (not this freeze): `setBufferBps(3000)` · `PSM_COLD` sweep split · agent refuse `keepOpenSweep` that drains below buffer.

### Bank-run drill (document, freeze)
1. Simulate redeem 20% of eUSD float against reserves.  
2. Confirm buffer holds; yield unwind script path named.  
3. If fail → raise COLD % before any new USDC capture campaign.

---

## Refined campaign order (complete war + peace)

```
0  SPARK     HOT ≥ 0.02 ETH
1  SMOKE     agent.firePayroll (small) · observe · pause
2  EXIT LAW  buffer bps + buyGem never-die · cold wallet named
3  SHIELD    eUSD settlement default · multi-gem LSR · wallet map
4  CAPTURE   PSM/ocean/bond/agent harvest (existing war plan)
5  PHASE2    builder MEV only after 0–3 green
```

No Step 4 without 0–3. That is how the elephant stays awake without charging off a cliff.

---

## 100-word CN refine (phone)

Scribe is right: war without spark, shield, and gate fails. Step 0 — put **≥0.02 ETH** on HOT; Base gas is cents, dust is the killer. Shield — **not** a Circle-freeze mixer; settle in **eUSD**, multi-rail gems, segregated wallets, rotate HOT. Exit — **≥30% USDC cold** for `buyGem`; never pause redemptions while reserves remain; yield max 30% and unwindable in a day. Then fire capture. Crown agent/LSR/BAMM already live — bind buffer law next lift. Bootstrap, sovereignty, redemption: fortress **with** a gate.

---

## One-block

```
FREEZE=cn-bootstrap-shield-exit
SPARK=HOT≥0.02ETH · gas=cents not millions
SHIELD=eUSD settle + multi-rail + wallet seg · NO mixer-vs-Circle
EXIT=≥30% USDC cold · buyGem never-die · yield≤30%
ORDER=0 spark → 1 smoke → 2 exit law → 3 shield → 4 capture → 5 MEV
LIVE=agent/LSR/BAMM/vault already on Base
```

---

## Cross-refs
- `CROWN-INTEGRATION-LIVE.md` · `FREEZE-CN-ENGINEER-HANDOFF-BUILD.md`  
- `FREEZE-ELITE-USDC-INGRESS.md` · `FREEZE-REPAY-WEDGE-MENU.md`  
- `AGENT-AAVE-BETTER-PLAN-100.md`  
