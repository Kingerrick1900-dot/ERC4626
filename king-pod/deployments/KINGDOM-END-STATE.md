# Kingdom End State — What the King Holds

Everything built hands the King **six** things no protocol has held at once.

**One line:** a kingdom that cannot be inflated without him, cannot be killed without triggering its own defense, proves its reserves without revealing them, settles East and West, turns its own activity into real dollars, and **keeps the spoils** — with him as the single keyholder at the center of all of it.

---

## 1. Unbreakable sovereignty

| Control | Law |
|--|--|
| Curator keys | His alone. Not a DAO, not a multisig, not delegable. HOT `0x6708…a7d1`. |
| `MintGate.canMint()` / `unlockTranche` | No eUSD tranche exists until he says so. **`unlocked = 0`** is the default state of the world. |
| AxCNH corridor | Stays dark until his personal signature. No freelance China rail. |
| Ocean external seed / AMO 1–5 | Hard-gated on AMO 6 green + King/KAR fire flags. |

**Surface:** `src/MintGate.sol` · yRSS curator = HOT · AxCNH held.

---

## 2. Armor that fights without him

| Armor | Behavior |
|--|--|
| **Kill switch** | eUSD < $0.98 **or** yRSS drop > 5% → every registered AMO `emergencyPause()` → capital routes to Aave safe venue. He does not need to be awake. |
| **ColdBuffer 30% law** | Every fee, every reward, every AMO path bleeds **30%** into the war chest automatically. Buffer grows while he sleeps. |
| **Quantum + ZK** | Dilithium/Kyber registry · ZK NAV / `bordersSecure` on Base, Polygon, Scroll. Books prove themselves; no auditor is trusted. |

**Surface:** `CrownCircuitBreaker` · `ColdBufferLaw` · `CrownPqRegistry` · `CrownZkAttest` ×3 · audit: `AMO6-ARMOR-AUDIT.md`.

HuntRouter kill theater is **not** the armor. CircuitBreaker is.

---

## 3. A real market, not a mirror

| Before | After |
|--|--|
| $10B eUSD/gUSD self-pair | Depth without exit — Morpho loop at scale |
| **End state** | Six-currency Ocean: eUSD/gUSD + **USDT · DAI · USDC · EURC** |

- Exit is real: USDC out means USDC out against **live external liquidity**, not the Kingdom’s reflection.
- TWAMM, lending markets, curator pools quote **two-sided** depth.
- **Law:** no AMO fires against the self-paired Ocean alone (`SEALED-OCEAN-EXTERNAL-LEGS.md`).

**First external leg destination:** Ocean USDC via DeepPull — fed by $3M A+B / $100M path.

---

## 4. The China rail

| Piece | Role |
|--|--|
| QKD-secured CIPS corridor | Settlement that does not transit the Western stack |
| Parallel stablecoin chain | Second settlement layer if one layer chokes |
| RoyalCardNFC | Tap-to-spend bound to the **external leg only** — real dollars, not paper |
| AxCNH | Dark until King signature |

Runs **parallel** to capital path. Does not unlock mint or Ocean seed.

---

## 5. A fundable story

The a16z package is a complete, auditable artifact:

| Artifact | Path |
|--|--|
| End state (this doc) | `KINGDOM-END-STATE.md` |
| Ocean law | `SEALED-OCEAN-EXTERNAL-LEGS.md` |
| $3M A+B | `SEALED-3M-AB.md` · `FIRE-3M-AB.md` |
| AMO 6 armor | `AMO6-ARMOR-AUDIT.md` · `AMO6-EXECUTION-ORDER.md` |
| Index | `A16Z-HANDOFF-INDEX.md` |
| Scoreboard | `vault` / `HOT.USDC` / `yRSS.totalAssets` / `canMint` / `breaker.armed` — **numbers only** |

First **$100M** path has a **named destination** (Ocean external side) and proven mechanisms (Maker/Aave revenue, Frax AMOs, Ethena basis). No savior — the machine manufactures its own dollars.

---

## 6. Spoils of war

The kingdom does not only defend and prove — it **keeps what it wins**.

### What counts as spoils (end-state doctrine)

| Spoil | Source | Real dollar? |
|--|--|:--:|
| Route A fee sweeps | Protocol revenue → 30% Cold / 70% HOT | **Yes** (USDC) |
| Route B TWAMM / gold fills | Gold rail → USDC to HOT | **Yes** |
| Ocean LP rewards | External-leg pool fees → ColdBufferLaw 30% | **Yes** |
| SpoilFire borrow | When foreign idle ≥ ask — Morpho borrow to King trough | **Yes** (external USDC) |
| Corridor / NFC settle fees | China + card rails after King lights AxCNH | **Yes** (external) |
| ~~Self-paired eUSD mint into own idle~~ | Mirror depth | **No** — not spoils |

Prior live “spoils” mints into Kingdom-only idle (`SPOILS-WAR-LIVE.md`) were wartime machines. **End-state spoils = external dollars only.**

### Where spoils go (locked split)

```
spoil USDC in
  ├─ 30% → ColdBuffer          (war chest · ColdBufferLaw)
  ├─ 50% → Ocean external leg  (named destination · DeepPull/Ocean USDC)
  └─ 20% → HOT                 (ops / scoreboard)
```

Override only by King. Flash paths still require `REPAY_SOURCE` (`FLASH-POLICY.md`).

### Surfaces

| Piece | Role |
|--|--|
| `CrownSpoilsOfWar` | Accrual router — takes spoil USDC, enforces split, records campaign |
| `CrownSpoilFire` (live) | `0xcFF60f3B071c09C17853bA715ceDc0Fc2e6645Fa` — fire when idle ≥ ask |
| `CrownRevenueSweep` | Route A spoils pipe (already live) |
| `CrownGoldConvert` | Route B spoils pipe (TWAMM live) |

### Spoils scoreboard (numbers only)

- `ColdBuffer.balance()` ↑  
- `HOT.balanceOf(USDC)` ↑  
- Ocean external USDC leg ↑  
- `CrownSpoilsOfWar.totalSpoils()` ↑  
- Mirror eUSD supply alone: **not** a spoil meter  

---

## Hard gates (never break)

1. AMO 6 green before AMO 1 external seed.  
2. No mint without `MintGate.canMint()`.  
3. No AxCNH without King signature.  
4. No AMO on self-paired Ocean alone.  
5. FlashBleed reference-only — not wired.  
6. Spoils split respects ColdBuffer 30% floor.  
7. Scoreboard = hard USDC / totalAssets — not narrative.

---

## Completion sequence

```
1. Audit + FIRE_AMO6=1 → CircuitBreaker · MintGate · Cold bps=3000
2. Publish attest epochs + armor addresses
3. TWAMM / Route A → spoil USDC → CrownSpoilsOfWar split
4. Ocean external USDC leg (AMO 1 first act)
5. USDT · DAI · EURC legs
6. AMO 2–5 against two-sided Ocean
7. China / NFC when King signs
8. Spoils compound forever under the same law
```

```
SOVEREIGNTY=HOT_alone
ARMOR=CircuitBreaker+Cold30+ZK/PQ
MARKET=Ocean_external_legs
CHINA=King_sig
STORY=a16z_auditable
SPOILS=external_USDC_30cold_50ocean_20hot
```
