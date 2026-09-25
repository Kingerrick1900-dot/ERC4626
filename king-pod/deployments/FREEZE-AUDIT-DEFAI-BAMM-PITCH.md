# FREEZE AUDIT — DeFAI agent + BAMM pitch (“no human at the door”)

**Mode:** FREEZE · audit only · **no deploy**  
**Pitch audited:** Autonomous DeFAI agent (self-saving loop) + Frax BAMM as backups that remove waiting on a human buyer.  
**Doctrine touch:** King’s machines + belief · CrownKingAgent allowlist · minted ocean real.

---

## Headline verdict

| Claim in the pitch | Audit |
|--|--|
| Waiting on one human buyer is not a 2026 strategy | **Agree** — doctrine fit. Strategy = machines King owns. |
| “Exact infrastructure already exists and is live” for mint eUSD → Morpho idle → PSM open **without fuel** | **Overclaim.** Live pieces exist; they do **not** mint Circle or fill empty USDC books by existing. |
| Deploy agent + BAMM and the door walks itself for **USDC payroll** | **Half-true.** Agent can **execute allowlisted Crown law 24/7**. BAMM can **venue** own-stable capital. Neither invents Circlesupply−borrow. |
| Tools live · code OSS · King commands · machine executes | **Keep as posture** — with **hard allowlists** on **our** contracts, not a foreign “treasury brain.” |

**Bottom line:** The pitch is right to reject human-hostage strategy. It is wrong where it sells AgentFi / BAMM as a substitute for **named machine surfaces** (mint, ocean LP, Morpho coll, PSM gem). Deploy the **executor of King law**, not a myth that LLM + OSS = Circle.

---

## Option 1 — Autonomous DeFAI agent (self-saving loop)

### What is real

| Piece | Status |
|--|--|
| AgentFi / agents managing DeFi capital | **Real industry trend** (yield bots → LLM agents; Aave **MCP** lets agents read/simulate and prep **unsigned** txs — human/signing module still signs). |
| On-chain **spend policy** (per-tx / daily / allowlist / pause) | **Real OSS on Base:** SpendOS, AgentWallet SDK, Synthesis-hack vaults (ShadowTrader / Antigravity-class DelegatedVault). |
| Self-hosted executor calling **King** contracts | **Fits doctrine** — same as `AGENT-DEPLOY-PLAN-100.md` (CrownKingAgent). |

### What is false or stretched

| Pitch line | Truth |
|--|--|
| Aave founder: agents already manage capital; **25–50% soon** | **Unverified / mis-attributed** in search. Live fact = Aave **MCP** + AgentFi narrative — not a Stani mandate that half of TVL is agent-run, and not a Base eUSD minter. |
| “Open-source **synthesis-agent** on Base” runs mint eUSD, seed Morpho, harvest idle, keep PSM open | **Category mash.** Synthesis-hack agents = spend-capped **swap/vault** demos. **None** are wired to HOT `mint`, yRSS, PARK, or multi-PSM. Wiring = **our** CrownKingAgent job. |
| Agent is the liquidity provider / banker that removes counterparties | Agent can **call** `mint` / `reallocate` / `supply` / `pokePeel`. It cannot create **unmatched USDC idle** or PSM gem without a **USDC surface** (wallet, foreign book+coll, inbound `sellGem`). |
| Agent-Mesh “auto-sell after buys” = kingdom self-save | **Foreign product analogy.** Useful pattern (lock profit) — not deployed kingdom infra. |

### Kingdom fit (freeze rank)

**KEEP as Option A for CrownKingAgent:** self-hosted runner + **on-chain spend vault** (caps) + allowlist = ocean seeder, KingRail, Unlatch/DeedPeel, yRSS curator fns, bond/BAMM when live. Hard refuse: gasPark, matched re-borrow, foreign spender, uncapped `mint` to random sinks.

**REJECT as sold:** “Deploy synthesis-agent and Morpho/PSM payroll solves itself.”

---

## Option 2 — Bonding AMM (Frax BAMM)

### What is real

| Piece | Status |
|--|--|
| Frax **BAMM** | **Real** — `FraxFinance/public-frax-bamm` · docs: oracle-free · debt/collateral in **√(x·y)** · LP rented as liquidity · no external oracle required for solvency math. |
| “Hidden” elite contract / AMM+lend in one | **Fair label** for research. |
| Brila **Elara** | **Real** separate product (CLMM treasury + CDP / elUSD). Analogy only — **not** a BAMM drop-in and **not** Base eUSD ocean. |

### What is stretched

| Pitch line | Truth |
|--|--|
| Needs **no external liquidity** | Lenders **are** the liquidity (LP in). For **eUSD/gUSD** that is **mint–mint** — self-contained **kingdom** market. Still **≠** Circle unless a leg is USDC (or someone swaps in). |
| “Instead of waiting for a human to buy eUSD with USDC, BAMM creates the market” | Creates / deepens **own-stable** borrow+swap venue. Does **not** force USDC into Landing. Buyers/renters still move value; mint alone fills both legs. |
| Drop onto Aero ocean tomorrow | BAMM expects **Fraxswap-style** pair. Ocean is **Aerodrome stable** `0x8C009d…`. Needs **fork/adapt** or Fraxswap pool of eUSD/gUSD — engineering, not a one-tx clone. |

### Kingdom fit (freeze rank)

**KEEP as Option B (code research):** BAMM-class on **eUSD/gUSD** (or eUSD/USDC after PSM gem) = elite own-market engine aligned with minted billions doctrine. Pair with **bond** (discount inventory → USDC/ETH) when King wants POL ingress.

**REJECT as sold:** “BAMM alone ends the USDC door problem.”

---

## Pitch verdict vs King law

| Pitch closer | Audit rewrite |
|--|--|
| “You do not need one person to walk through the door” | **True** as strategy. |
| “Deploy the agent that walks through it for you” | **True** only if agent = **allowlisted Crown executor** under King law. |
| “Deploy the BAMM that creates the market where there was none” | **True** for **kingdom-stable** market. **False** as Circle mint. |
| “The tools are live. The code is open-source.” | **True** as **patterns** (spend vaults, public-frax-bamm). **False** as plug-and-play onto HOT mint/PSM/Morpho payroll. |

---

## Ordered freeze plan (no build until `FIRE_AGENT=1`)

1. **CrownKingAgent** — King-gated allowlist + on-chain spend caps (SpendOS-class pattern, **our** targets). Dry-run watch → fork-pass → auth/revoke.  
2. **BAMM research spike** — map Frax BAMM → eUSD/gUSD (Fraxswap fork vs Aero adapter). Fork-test solvency on mint–mint LP.  
3. **Bond module** (Olympus-class) — optional POL when King wants discounted eUSD/gUSD → USDC/ETH.  
4. **Never** point uncapped LLM at HOT key; **never** call foreign DeFAI the treasury brain.

---

## One-block

```
PITCH=right reject human-hostage · wrong sell AgentFi/BAMM as Circle printer
OPT1=KEEP as CrownKingAgent+spend policy on OUR rails · REJECT synthesis myth
OPT2=KEEP BAMM research on eUSD/gUSD · REJECT “no external = USDC”
AAVE 25-50%=unverified · MCP=real unsigned helper
NEXT=FIRE_AGENT=1 only after fork-pass allowlist · freeze holds
```

---

## Cross-refs

- `AGENT-DEPLOY-PLAN-100.md` · `FREEZE-AI-AGENT-OLYMPUS-BAMM-AUDIT.md`  
- `FREEZE-MINTED-BILLIONS-REAL.md` · `FREEZE-KING-USDC-ETH-REALITY.md`  
- `FREEZE-REPAY-WEDGE-MENU.md` · `FREEZE-ELITE-USDC-INGRESS.md`  
