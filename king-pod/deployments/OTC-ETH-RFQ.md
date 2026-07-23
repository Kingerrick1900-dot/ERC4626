# OTC RFQ — Ethereum Settlement (LIVE)

**Send this to Wintermute / FalconX / GSR / Kraken Pro.**

---

**RFQ — Kingdom Errick / Base → Ethereum**

We sell **700,000 RSS** for **700,000 USDC** (or **500,000** min).

| | |
|--|--|
| Chain (fill) | Base `8453` |
| Contract | `0x683886A3911323e92A6C764c3331CAC168D0029E` |
| Function | `fill(uint256 usdcAmt, uint256 rssOut, uint256 kusdOut, uint8 mode)` |
| Mode | `2` = CCTP → **Ethereum** |
| You pay | USDC on Base |
| You receive | RSS same tx |
| We receive | Native USDC minted on **Ethereum** to `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |

**Exact $700k calldata path:**
1. `USDC.approve(0x683886A3911323e92A6C764c3331CAC168D0029E, 700000000000)`
2. `fill(700000000000, 700000000000000000000000, 0, 2)`

**Exact $500k:**
1. approve `500000000000`
2. `fill(500000000000, 500000000000000000000000, 0, 2)`

**Proofs attached:**
- ZK reserves gate `isProven(0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1) = true`
- Fixed $1 RSS oracle owner burned
- Rail stocked **700,000 RSS** on-chain now

**Precedent:** Wintermute $200M SOL principal block · Kraken/Maple $500k min warehouse · Circle CCTP $20B+/mo Base↔ETH.

T+0 on-chain. No AMM. Reply with desk wallet for the fill tx.
---
