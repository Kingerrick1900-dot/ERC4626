# CAPITAL POOLS PACKET — Phase 1–3 (RSS + BRETT)

**From:** Kingdom of Yahudah · Curator yRSS  
**Ask:** Put USDC facing Kingdom Morpho Blue markets via Public Allocator / vault allocation.  
**Phase 1 need:** unlock **≥ $500k** idle (or desk fill) → Landing.

---

## Markets to open (both)

### 1) RSS / USDC (PRIMARY — Phase 1 cash line)

| | |
|--|--|
| Market id | `0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794` |
| Loan | USDC `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| Collateral | RSS `0x7a305D07B537359cf468eAea9bb176E5308bC337` |
| Oracle | FixedOracle **$1** `0x284EC3…2e` · owner **`dEaD`** |
| LLTV | **77%** |
| IRM | AdaptiveCurve |
| Proof | Prior **~$9M** borrow against this mark |
| Request | PA **maxIn ≥ $500k–$5M** (Phase 1 floor **$500k**) |

### 2) BRETT / USDC (EXPAND — Phase 2+)

| | |
|--|--|
| Market id | `0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16` |
| Loan | USDC |
| Collateral | BRETT `0x532f27101965dd16442E59d40670FaF5eBB142E4` |
| Oracle | UniV3 TWAP `0x3378E48f…2619` |
| LLTV | **62.5%** |
| Request | Enable market in vault + PA **maxIn ≥ $100k** to start (scale later) |

---

## Kingdom vault (already curator-grade)

| | |
|--|--|
| yRSS | `0xF80C0529bD94C773844E459853CD91B9263dD525` |
| Fee | **10%** → King |
| PA | Enabled · ~$700k flow caps on RSS & BRETT |
| Caps | RSS **$14M** · BRETT **$2M** |

Depositors earn from borrower demand. Kingdom already ran nine-figure util on RSS.

---

## Target capital pools (Base)

| Pool | Address (ref) | Ask |
|------|----------------|-----|
| Gauntlet USDC Prime | `0xeE8F…4b61` | maxIn on RSS (then BRETT) |
| Steakhouse Prime USDC | `0xBEEF…83b2` | maxIn on RSS |
| Steakhouse USDC | `0xbeeF…8183` | maxIn on RSS |
| Steakhouse HY USDC | `0xBEEF…878F` | maxIn on RSS |

Also: Morpho app listing visibility · curator BD · forum surface.

---

## Parallel (no vault required) — Desk $500k Phase 1

Desk `0xDbf7…065D` · **700k RSS @ $1 LIVE** · proceeds → Landing.  
Phase 1 fill: `buyWithUsdc(500000000000)` ($500k).  
Packet: `OPS-COUNTERPARTY-PACKET.md`

---

## Fees · yield · gov (Phase 2–3)

| Lever | Play |
|-------|------|
| Performance fee | 10% live — rises only after Phase 1 on King GO |
| Yield magnet | High util history on RSS book |
| Gov | Stay governance-approved IRM/LLTV · grow yRSS as public USDC vault |
| Emissions (later) | Aero incentives only after Landing war chest (Phase 3) |

---

## Copy/paste ask (RSS — send now)

> Please set Public Allocator **maxIn ≥ $500,000** (prefer $1M–$5M) on Base Morpho market  
> `0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794`  
> (USDC loan / RSS collateral / FixedOracle $1 burned / LLTV 77%).  
> Kingdom curator vault: yRSS `0xF80C0529bD94C773844E459853CD91B9263dD525`.  
> Proven ~$9M prior utilization. Phase 1 unlock for sovereign borrower to Landing.

**Chief:** Pools with capital ↔ Kingdom markets. Phase 1 = $500k Landing.
