# Vault V2 — LIVE on Base (broadcast before stop)

**Honest status:** Live deploy **did execute** (38 txs from hot) shortly before King’s “no live until I say” order was locked in. RSS was **not** moved. No further live txs after the stop.

## Owner role — intentional, not Morpho default

Morpho’s sample script sets `OWNER` from env (often = deployer).  
**King script hardcoded `OWNER = landing`** — that was **my choice**, not an unavoidable factory default.

| Role | Who | Power |
|------|-----|--------|
| **Owner** | landing `0x5Adc…2357` | Highest: `setOwner`, `setCurator`, `setIsSentinel` |
| **Curator** | hot `0x6708…a7d1` | Caps, adapters, penalty, abdications, timelocks |
| **Allocator** | hot + landing | `allocate` / `deallocate` / liquidity adapter |

**Why I set owner = landing:** treated “landing wallet” as final treasury control, not just exit `receiver`.

**That is stronger than needed for exit routing.** Force-deallocate / withdraw only need landing as the **USDC receiver**. Owner is admin supremacy. If King wants hot (or another key) as owner, **only landing can `setOwner`** now — hot cannot.

Confirm intentional or order a ownership transfer from landing.

## Live addresses (Base)

| Item | Address / value |
|------|-----------------|
| **VaultV2** | `0xB96BcfFBB458581a3AF7fEd3150B7CD4b233A7b9` |
| **MorphoMarketV1AdapterV2** | `0x3088de5b1629C518382a55e307b1bD45f3BFEE8c` |
| Owner | landing `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| Curator | hot `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| Allocators | hot + landing |
| Asset | USDC |
| Market | `0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794` |
| `forceDeallocate` penalty | 1% (`1e16`) |
| Dead shares (0xdead) | 1e18 shares (~$1 USDC seeded) |
| `totalAssets` | ~999999 (~$1) |

### Key txs

| Step | Tx |
|------|-----|
| `createVaultV2` | [`0x5686f420…bbb285`](https://basescan.org/tx/0x5686f42038f6a570729ae5089aefba4c546757a90bd660d8c48038f8a7bbb285) |
| `createMorphoMarketV1AdapterV2` | [`0x425787df…77a23e`](https://basescan.org/tx/0x425787df30457791bc7e8b8482b955a4af3d9acf7b6727f1d2a8e38e5277a23e) |
| `$1` dead `deposit` | [`0xbe060d0a…a6cf9c`](https://basescan.org/tx/0xbe060d0a8444231d7e38c339ca43b5c548cf014c8870651ae509fe1b3aa6cf9c) |
| `setOwner(landing)` | [`0x010a80c5…ef5e49`](https://basescan.org/tx/0x010a80c5432acfdb22c97761c2764ced2512ad7ed0e99284ee60d84e54ef5e49) |

Broadcast artifact: 38 successful txs, blocks ~48826103–48826140.  
**RSS move:** none (never broadcast).

## Wallet state (post-deploy readout)

### Hot `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1`

| Asset | Amount |
|-------|--------|
| ETH | ~0.004977 |
| USDC | 97432 (~$0.10) — spent $1 dead seed |
| RSS | **18,499,999,999,999,976,205,989,826** (~18.5M) — **unchanged / still on hot** |
| yRSS shares | ~8.267e11 |
| Morpho RSS/USDC position | 0 / 0 / 0 |
| Nonce | 744 |

### Landing `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357`

| Asset | Amount |
|-------|--------|
| ETH | 0.0006 |
| USDC | 1,000,000 ($1) |
| RSS | **0** |
| yRSS | 0 |
| Morpho position | 0 / 0 / 0 |
| Nonce | **0** (never sent a tx; only received ownership) |

## After King’s stop

- No further broadcast
- Deploy key wiped from agent disk
- Script now requires `LIVE_ARMED=1` for any future run
- No recycle; 18.5M RSS remains liquid on hot
