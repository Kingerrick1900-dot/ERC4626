# FREEZE — Audit: AI-agent treasury + Olympus/BAMM backups · what *our* agent does

**Mode:** FREEZE · no deploy of Sperax/Evernorth/Olympus/BAMM  
**Question:** (1) Are Options 1–2 real elite paths? (2) What is the kingdom’s current “automation agent” actually doing?

---

## A) What our automation is doing **now**

| Layer | What it is | Live behavior |
|--|--|--|
| **Cursor / Cloud Agent** | LLM ops under King handoff | **Info / code under freeze** — not an on-chain treasury AI executing trades |
| **Morpho roles** | HOT = yRSS **owner + curator + allocator** | Instant `reallocate` / caps / queue — **human or script fires**, not autonomous AI |
| **Public Allocator** `0xA090…0467` | Morpho liquidity router | Flow caps set by us; **foreign** Gauntlet/Steakhouse still **maxIn=0** into RSS |
| **`watch_maxin_fire.py`** | Poller | Watches `maxIn`; prints FIRE — **does not broadcast** |
| **Crown\* / Fire\* / Carry\*** | Foundry one-shot keepers | Atomic Morpho free/seed/carry — **carry HALTED** (OPS-FREEZE) |
| **CrownSpoilFire** `0xcFF60…645Fa` | Live bytecode (~2.8kB) | PA `reallocateTo` → borrow path when caps open — **gated**, not looping AI |
| **Ocean / mint / PSM** | Sovereign rails | Ocean **5B/5B** · PSM USDC **$0** · mint real · no AI manager |

**Verdict:** There is **no** deployed SperaxOS/Evernorth-style AI treasury agent managing kingdom capital. Closest “automation” = Morpho curator law + optional PA + alert scripts + King-gated forge fires. Under **OPS-FREEZE / handoff freeze**, that stack is **not** auto-running yield.

---

## B) Option 1 — AI-Agent Treasury (Evernorth / SperaxOS)

| Claim | Audit |
|--|--|
| Evernorth + t54 AI on **$1B+ XRP** | **Real company narrative** (press 2026): raise + XRPL treasury + agentic infra. Not a Base eUSD contract you can point HOT at today. |
| SperaxOS “500+ agents”, USDs ~4.78% | **Real product** (SperaxOS public/open agent index; USDs = their yield stable on Arb/BNB). Off-the-shelf **workspace**, not kingdom-sovereign mint. |
| “Agents are the someone that runs the treasury” | True for **their** stacks. For King: would mean **outsourcing execution** to foreign agent runtime + their risk layer — conflicts with “we built the shit to save ourselves” unless self-hosted under King keys with hard allowlists. |

**Fit:** Optional **ops layer** later (self-host SperaxOS-class tools to call **our** Crown contracts). Does **not** mint Circle or replace PSM. Does **not** exist on-chain in this repo today.

---

## C) Option 2 — POL bonds (Olympus Pro) + Frax BAMM

| Claim | Audit |
|--|--|
| Olympus Pro bonds → permanent POL | **Real pattern:** sell discounted inventory for stables/LP → treasury **owns** LP. Needs **buyers with assets**. gUSD/eUSD inventory helps **supply** the bond offer; does not force USDC in without counterparties. |
| “Frax and Aave GHO use this” | POL/bonding is Frax/Olympus-adjacent; GHO’s main Circle door is **GSM**, not primarily Olympus Pro. |
| Frax **BAMM** (`public-frax-bamm`) | **Real elite primitive:** AMM + lending, debt in `sqrt(K)`, **no external oracle**, LP rented as liquidity. Needs an underlying **Fraxswap-style pair** and LPs. On **eUSD/gUSD** it strengthens **own-stable** venue (like ocean+lend). Still **mint–mint** unless one leg is USDC. |

**Fit:** Strongest **on-chain** backup aligned with sovereign mint:  
1) Bond eUSD/gUSD (or LP) for USDC/ETH when MM bites → POL.  
2) Optional BAMM fork on **eUSD/gUSD** (or eUSD/USDC once PSM has gem) for oracle-free own market.

---

## D) Ranking for the King (freeze)

| Priority | Move | Why |
|--|--|--|
| **1 Keep** | Curator + PA + Crown fires under King go | Already built; not AI theater |
| **2 Build (code)** | Olympus-style **bond** (eUSD/gUSD → USDC/ETH) | Elite POL ingress when counterparty pays |
| **3 Build (code)** | Research **BAMM-class** on ocean pair | Self-contained swap+lend on minted inventory |
| **4 Optional** | Self-host agent runner that only calls allowlisted Crown/PSM | AI as **operator**, not savior |
| **Reject as “current agent”** | Claiming Spoiler/watch scripts are Evernorth | Category error |

---

## Plan (≤100 words)

Do not deploy Sperax/Evernorth as the treasury brain. Our agent today is **King-gated Morpho curator + scripts**, frozen. Elite backups that match mint power: (1) fork/build a **bond** that sells eUSD/gUSD for USDC/ETH into Landing POL; (2) evaluate **BAMM** on eUSD/gUSD ocean LP for oracle-free own market. AI agents only as a **self-hosted caller** of those contracts with hard allowlists. Fork-test bond buy exact amounts before fire. Freeze holds.

---

## One-block

```
OUR AGENT NOW = curator/PA + watch scripts + Crown fires (FROZEN) · NOT Sperax/Evernorth AI
OPT1 AI = real vendors · optional ops layer · not Circle mint
OPT2 bond+BAMM = real on-chain elite · needs buyers / own pair
NEXT = bond design fork-test · not outsource treasury brain
```
