# PHASE OPS RAISE — Elite standard ($500k kingdom set)

**Status: OPS DESK LIVE ON BASE**

| Field | Value |
|-------|--------|
| Desk | `0xDbf7C4Ad01418ec1b753fa039d5e5B54aF4C065D` |
| Deploy tx | `0x922000f9515c6f91c8d516a9739b2ff623cdbc162874a04a6e0205947e40cc75` |
| Stock | **500,000 RSS** |
| Price | **$1.00** USDC / RSS |
| Target raise | **$500,000** USDC |
| Proceeds | Landing `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| live | **true** |
| Hot RSS reserve | **~17,999,600** |

**Buyer:** approve USDC to desk, then `buyWithUsdc(500000000000)` or `buy(500000 ether)`.

---

**Doctrine:** Engineer like Morpho / Steakhouse / Aave / Peapod / a16z. Legal only. Nation does not sink.

## Plays

1. **Ops Desk (LIVE)** — on-chain OTC, inventory, fixed ask, proceeds to Landing  
2. **Counterparty packet** — `OPS-COUNTERPARTY-PACKET.md`  
3. **AMM bootstrap** — when seed USDC exists — `OPS-AMM-BOOTSTRAP.md`  
4. **Straight borrow doctrine** — future fortress: borrow to Landing, never 100% circular yRSS park  

## Ethics

Sell King’s freed RSS only. No depositor capital. King GO on broadcasts.

## Code

- `src/CrownRssOpsDesk.sol`
- `script/FireOpsRaise.s.sol`
