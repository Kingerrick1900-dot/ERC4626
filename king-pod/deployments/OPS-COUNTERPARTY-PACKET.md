# Kingdom Ops Raise — Counterparty Packet

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

## Desk terms (default)

| | |
|--|--|
| Size | **$500,000** USDC |
| Inventory | **500,000 RSS** |
| Price | **$1.00** USDC per RSS (oracle peg) |
| Proceeds | Landing `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| Settlement | On-chain `CrownRssOpsDesk` — USDC in, RSS out, same tx |

Buyer: `buyWithUsdc(500000000000)` or `buy(500000 ether)`  
USDC approve desk first.

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
