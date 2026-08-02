# Kingdom Ops Raise — Counterparty Packet

**Chief plan:** `CHIEF-3-PHASE-EXPAND.md` — **Phase 1 = $500k to Landing.**  
**Also:** `BOND-COUNTERPARTY-PACKET.md` · `OUTBOUND-DUAL-RAIL.md` · `CHIEF-PLAY.md`

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
- Kingdom opened a **$9M** borrow against RSS (self-seed fortress), then **cleared Morpho to zero** and freed inventory to hot.
- Zero debt tx: `0x453b51c6511266d274d257e62c1d00d83f6389d50cdeccb2806aeaf9245de635`

---

## Desk terms (LIVE) — Phase 1 fill $500k

| | |
|--|--|
| Desk | `0xDbf7C4Ad01418ec1b753fa039d5e5B54aF4C065D` |
| One-click helper | `0xeA454FAD0115A8131C3E10bC117A6584f649356b` |
| Bond @ $0.97 (alt rail) | `0x2D743eF8bf8eE188F44239Acc1e4795fe8cA3039` — see `BOND-COUNTERPARTY-PACKET.md` |
| Phase 1 ask | **$500,000** USDC (King target) |
| Inventory available | **700,000 RSS** @ **$1.00** |
| Proceeds | Landing `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| Settlement | On-chain `CrownRssOpsDesk` — USDC in, RSS out, same tx |
| live | **true** |

**Phase 1 buyer:** approve USDC → helper `fillPhase1()` for exactly **$500k**, or desk `buyWithUsdc(500000000000)`.  
Full desk book: **700k @ $1**. Bond rail: **520k @ $0.97** on `0x2D743…3039`. Partial fills OK on all rails.

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
