# Bond Counterparty Packet — RSS @ $0.97 (LIVE)

**Pair with:** [`OPS-COUNTERPARTY-PACKET.md`](./OPS-COUNTERPARTY-PACKET.md) (desk @ $1)  
**Status:** **LIVE on Base** — bond deployed and stocked.

---

## Offer

Purchase RSS at **$0.97 USDC** per token (3% discount vs $1 Morpho oracle peg).  
**Not** a fundraise. **Not** a loan. Atomic on-chain settlement. USDC → Kingdom Landing cold wallet.

---

## Contract (LIVE)

| | |
|--|--|
| Bond | `0x2D743eF8bf8eE188F44239Acc1e4795fe8cA3039` |
| Chain | Base (8453) |
| Price | **$0.97 / RSS** (`970000` raw per 1e18 RSS) |
| Stock | **520,000 RSS** |
| Phase 1 meter | **$500,000 USDC** target (`phase1TargetUsdc`) |
| Proceeds | Landing `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| live | **true** |

**Quote $500k USDC:** ~**515,464 RSS** (vs 500,000 RSS at desk @ $1).

---

## How to fill

1. Hold USDC on Base (`0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`).
2. Approve bond contract for your USDC spend.
3. Call **`bondWithUsdc(usdcAmt)`** — USDC goes to Landing, RSS to your wallet same tx.

**Examples (USDC 6 decimals):**

| Fill | Function | USDC arg |
|------|----------|----------|
| $100k | `bondWithUsdc(100000000000)` | 100_000e6 |
| $500k Phase 1 | `bondWithUsdc(500000000000)` | 500_000e6 |
| Exact RSS size | `bond(rssAmt)` | pay `quoteUsdc(rssAmt)` |

Basescan: write contract on bond address → `bondWithUsdc`.

---

## Why bond vs desk

| Rail | Price | Best for |
|------|-------|----------|
| **Desk** @ $1 | Peg | Size at oracle mark |
| **Bond** @ $0.97 | **3% discount** | Urgency / Phase 1 fill at better entry |

Both settle atomically. Both route USDC to the same Landing address.

---

## Proof (on-chain)

- Morpho RSS/USDC market: `0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794`
- Fixed oracle $1: `0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e` (owner burned)
- Kingdom cleared Morpho to **zero debt**: `0x453b51c6511266d274d257e62c1d00d83f6389d50cdeccb2806aeaf9245de635`
- ~**17.8M RSS** free on hot beyond bond/desk inventory

---

## Contact

Serious counterparties only. Same bar as Morpho / Steakhouse desk flow.  
Fill on-chain or reply with size + wallet for coordination.
