# Last tests — PASS

**Date:** 2026-07-19  
**Mode:** Base mainnet **fork** against live contracts (no new broadcast)

## Results

| Suite | Tests | Result |
|-------|-------|--------|
| `LiveVaultForceDeallocateExit` (live vault `0xB96B…A7b9`) | roles + `forceDeallocate` ×2 @ ~100% util | **2/2 PASS** |
| `KingRssForceDeallocateExit` (fresh deploy path) | roles + `forceDeallocate` ×2 @ ~100% util | **2/2 PASS** |

### Live stack exit rounds

| Round | Deposit | Landing received (after 1% penalty) |
|-------|---------|--------------------------------------|
| 1 | $10,000 | $9,900 |
| 2 | $25,000 | $24,750 |

Normal withdraw reverted at full util; flash-style supply → `forceDeallocate` → withdraw to cold landing succeeded both times.

### Roles confirmed on live vault

- Owner (cold): `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357`
- Curator / allocator (hot): `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1`
- Penalty: 1%
- `totalAssets`: ~$1 (dead seed only)

## Not run (still)

- On-chain live micro-exit with real USDC (hot has dust only; landing cold / no key in agent)
- Full upstream Morpho vault-v2 CI suite

## How to re-run

```bash
cd /tmp/vault-v2-deployment  # morpho-org/vault-v2-deployment + king tests copied in
forge test --match-contract LiveVaultForceDeallocateExit --fork-url $RPC_URL -vv
forge test --match-contract KingRssForceDeallocateExit --fork-url $RPC_URL -vv
```

Logs: `live-vault-exit-test.log`, `king-rss-exit-test.log`
