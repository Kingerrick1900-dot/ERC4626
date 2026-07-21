# Kingdom Ops Raise — Counterparty Packet

**Chief plan:** `CHIEF-3-PHASE-EXPAND.md` — **Phase 1 = $500k to Landing.**  
**Also:** `CHIEF-PLAY.md` · `CAPITAL-POOLS-PACKET.md`

**Offer:** Purchase RSS (Kingdom working asset) for USDC on Base.  
**Not** a fundraise into opacity. **Not** a request to lend. Clean asset sale.

---

## Asset

| | |
|--|--|
| Token | RSS `0x7a305D07B537359cf468eAea9bb176E5308bC337` |
| Chain | Base |
| Role | Working collateral asset (Morpho FixedOracle $1) |
| Oracle | `0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e` (owner burned) |

---

## Proof of quality (on-chain history)

- Morpho Blue market RSS/USDC: `0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794`
- Kingdom opened a **$9M** borrow against RSS (self-seed fortress), then **paid the loan down to dust** and freed inventory to hot.
- Debt-free tx: `0xc925489272ccccdd13a4d6f64aeb4dc16ab941d2b2e2dce8b8ce6250aff16912`

---

## Desk terms (LIVE) — Phase 1 fill $500k

| | |
|--|--|
| Desk | `0xDbf7C4Ad01418ec1b753fa039d5e5B54aF4C065D` |
| Phase 1 ask | **$500,000** USDC (King target) |
| Inventory available | **700,000 RSS** @ **$1.00** |
| Proceeds | Landing `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| Settlement | On-chain `CrownRssOpsDesk` — USDC in, RSS out, same tx |
| live | **true** |

**Phase 1 buyer:** approve USDC → desk, then `buyWithUsdc(500000000000)`.  
Full book still available: `buyWithUsdc(700000000000)`. Partial fills OK.

---

## Why desks buy this

- Transparent oracle + Morpho market history  
- Atomic settlement  
- No off-chain custody story  
- Size is a **slice** of ~18.5M free RSS — deep reserve remains  

---

## Contact / fill

King GO arms the desk. Counterparty fills on Basescan.  
Packet for serious desks only — same standard as Morpho/Steakhouse counterparties.
