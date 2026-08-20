# RSS $1200 raise pipe — Phase 2

Payroll path: **arm RSS/$1200 on yRSS → seed idle → borrow $700k to Landing**.

## On-chain gates (live read 2026-08-19)

| Gate | State |
|--|--|
| RSS/$1200 on yRSS | **disabled** (run `ArmYrss1200`) |
| RSS/$1200 market idle | **~$0** (need seed) |
| Hot RSS free | **~15M** |
| Landing USDC | **~$2.41** |
| Steakhouse PA maxOut WETH | **~$559M** |
| Steakhouse PA maxIn RSS/$1200 | **$0** (Steakhouse curator must open, or Merkl suppliers) |

## Fire order

### 1 — Arm yRSS + PA flow (hot)

```bash
cd king-pod
KING_OK=1 forge script script/ArmYrss1200.s.sol:ArmYrss1200 \
  --rpc-url https://mainnet.base.org --broadcast --slow -vvv
```

Enables RSS/$1200 cap **$14M**, queue slot 0, PA **maxIn/maxOut $700k** on yRSS.

### 2 — Seed idle (pick one)

**A. Curator reallocate** (yRSS TVL only ~$365 today — not $700k alone):

```bash
KING_OK=1 forge script script/ReallocateYrssToRss1200.s.sol:ReallocateYrssToRss1200 \
  --rpc-url https://mainnet.base.org --broadcast -vvv
```

**B. PA pull** from Steakhouse WETH → RSS/$1200 (needs Steakhouse **maxIn** on RSS/$1200):

```bash
KING_OK=1 PA_VAULT=0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2 \
  PULL_USDC=700000000000 \
  forge script script/PaSeedRss1200.s.sol:PaSeedRss1200 \
  --rpc-url https://mainnet.base.org --broadcast --slow -vvv
```

**C. Merkl supply campaign** — `merkl-rss-1200-supply.json` (external USDC suppliers).

### 3 — Draw to Landing (when idle ≥ $700k)

```bash
KING_OK=1 forge script script/BorrowIdleToLanding.s.sol:BorrowIdleToLanding \
  --rpc-url https://mainnet.base.org --broadcast -vvv
```

Posts **850 RSS** collateral (@ $1200 / 77% LLTV buffer) if needed, borrows **$700k USDC** to Landing `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357`.

## Market IDs

```
RSS/$1200 = 0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88
ORACLE    = 0xb5840644142b341A6145335e2EBC82EeBc7Ae1b9  (price 1.2e27 = $1200/RSS)
```

## Phase 1 (Peapods PoD)

Peapods RSS/$1200 self-lend lights fUSDC util — **does not** create Morpho idle. See PR #117 / `PEAPODS-RSS1200-LIVE.md`.

## Fork test

```bash
forge test --match-contract BorrowIdleRss1200ForkTest -vvv --fork-url https://mainnet.base.org
```
