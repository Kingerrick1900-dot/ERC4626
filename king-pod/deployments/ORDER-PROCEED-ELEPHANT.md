# ORDER — PROCEED · The Elephant Walks

**Status:** Phase 0 · **3/4 green** · Item 3 blocks Claim · Claim **LOCKED**  
**PR:** #195  
**Doctrine:** `ZK_SHIELD=1` · `TRANSPARENT_OK=NO_ZK` · Safe King · HOT operator · `isProven(Safe)` on every fire · no temporary king transfer · no paper games

---

## Phase map

| Phase | Name | Status |
|--|--|--|
| **0** | Preconditions (lock all four) | **3/4 green** · Item 3 open |
| 1 | The Claim | LOCKED |
| 2 | The Engine | LOCKED |
| 3 | The Print | LOCKED |
| 4 | The Handover | Standing law |

---

## Phase 0 — Preconditions

### Item 1 — Confirm AMO 6 → **GREEN**

**Proof:** [`PROOF-PHASE0-AMO6.md`](PROOF-PHASE0-AMO6.md)

| Requirement | Live |
|--|--|
| `bordersSecure` Base / Polygon / Scroll | **true** ×3 (epochs 16 / 8 / 10) |
| Quantum signatures active | `CrownPqRegistry` keyCount **4** · Dilithium + Kyber active |
| NAV attestation live and public | Base epoch 16 NAV **255928771250431** ≥ thr **220e12** · proof `0xc363eaf0…` |
| Armor | Breaker armed / not tripped · MintGate locked · Cold 30% |

### Item 2 — Verify CrownGateV2 → **GREEN**

| Check | Live / evidence |
|--|--|
| Gate | `0x76fa390951fA31185490378F46B6e9F05bA4bC3b` |
| King (sole controller) | Safe `0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0` · `pendingKing=0` |
| Operator | HOT `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` = **true** |
| `zkGate` | `0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091` · `isProven(Safe)=true` |
| MarketParams | loan USDC · coll RSS `0x7a305D07B537359cf468eAea9bb176E5308bC337` · oracle `0x22E2F66a26eA8d01E0Bb4154ef4DfB0304a34f2d` · irm `0x46415998764C29aB2a25CbeA6254146D50D22687` · LLTV **77%** |
| `MARKET_ID` | `0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b` |
| Morpho | `0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb` |
| `paused` | **false** |
| Controls tested | Fork (`SimCrownGateV2`): kill switch pause/unpause under Safe · HOT cannot pause · rescue blocks RSS · only Safe initiates king transfer · MarketParams match |

### Item 3 — Collateral Ready → **NOT GREEN** (Claim blocker)

| Fact | Value |
|--|--|
| Gate Morpho collateral | **222521940922706875000000** RSS (~222.5k units) |
| Gate Morpho borrow | **~3,000,017 USDC** (market fully drawn) |
| Market idle USDC | **0** (`totalSupplyAssets == totalBorrowAssets`) |
| Safe wallet cbBTC / yRSS / RSS / USDC | **0** |
| Free collateral under Safe to post | **none observed** |

**To green Item 3:** Accepted collateral under Safe (or authorized Gate post path) sized to intended borrow at LLTV with buffer, **and** a Morpho market with verified idle USDC **> 0**. Current SOV market idle = **$0** — no new claim inventory.

### Item 4 — Risk Parameters Locked → **GREEN** (agent law)

| Parameter | LOCKED value | Enforcement |
|--|--|--|
| Max borrow / market | `min(idle_usdc × 50%, LLTV × coll_value × 85%)` · never exceed idle | Agent + script gate before `borrowUSDC` |
| Min health factor | **≥ 1.25** post-borrow | Agent reject if projected HF < 1.25 |
| ColdBuffer | **30%** (`minBufferBps = 3000`) | On-chain ColdBuffer + Spoils split |
| Kill switch | Breaker trip **or** Gate `setPaused(true)` by Safe **or** MintGate `canMint=false` | Live: armed / pause onlyKing / canMint false |

With idle = 0, max new borrow under this lock = **0** until idle appears.

---

## Phase 1 — The Claim (LOCKED)

1. Select market with **verified idle USDC** (publish full Morpho id + idle).  
2. Post collateral through Gate.  
3. Borrow conservatively (not max).  
4. Pay lender interest as required.  
5. ZK-attest every action (`isProven(Safe)`).

Success: real USDC in Gate/HOT · healthy HF · no liquidation path.

## Phase 2 — The Engine (LOCKED)

Priority: (1) Reserve/HOT · (2) ColdBuffer 30% · (3) audited yield · (4) RSS/Ocean only from surplus.

## Phase 3 — The Print (LOCKED)

Scale only when HOT USDC grown · HF above lock · external idle remains. No unconstrained printing.

## Phase 4 — The Handover (LAW)

Safe King · HOT operator · ZK sole truth · Kingdom survives its operators.

---

## Standing scoreboard (live @ proof blocks)

| Meter | Value |
|--|--|
| Phase 0.1 AMO6 | **GREEN** |
| Phase 0.2 Gate | **GREEN** |
| Phase 0.3 Collateral | **NOT GREEN** |
| Phase 0.4 Risk locks | **GREEN** |
| King | Safe |
| `isProven(Safe)` | true |
| HOT USDC | 164417 (~$0.16) |
| SOV market idle | **$0** |
| Claim | **LOCKED** |

```
ORDER=PROCEED_ELEPHANT
PHASE0_1=GREEN
PHASE0_2=GREEN
PHASE0_3=NOT_GREEN
PHASE0_4=GREEN
CLAIM=LOCKED
PROOF=PROOF-PHASE0-AMO6.md
NEXT=PHASE0_ITEM3_COLLATERAL_AND_IDLE
```
