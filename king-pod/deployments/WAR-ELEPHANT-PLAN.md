# War Elephant - Full Battle Plan

**Status: HOLD on multi-flash atomic strike.** See `WHY-FLASH-COMPLEXITY.md` — self-seed does not require 2×/3× Morpho flashes; that plumbing is fragile. King must pick simple ATTACK-only and/or IKR-FEED with real working capital before any live $1k.

## Objective

Take a **$9M loan against King RSS**, seed **live Vault V2** (forceDeallocate proven), then on order **FEED** liquid USDC to cold landing Cake.

| Role | Address |
|------|---------|
| Hot (daily / signer) | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| Landing (cold Cake) | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| Vault V2 | `0xB96BcfFBB458581a3AF7fEd3150B7CD4b233A7b9` |
| Adapter | `0x3088de5b1629C518382a55e307b1bD45f3BFEE8c` |
| RSS / USDC market | `0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794` |

## Safety - funds cannot "drop mid-tx"

### How Morpho flash works
ATTACK and FEED each run inside **one atomic flash**.  
If any step fails, **the whole transaction reverts**:

- No partial debt
- No partial vault deposit
- RSS never leaves king unless the full attack succeeds

`CrownSelfSeedV2` posts RSS **inside** the flash (not before). That removes the stuck-collateral risk.

### What "stuck to repay" would mean - and how we prevent it

| Situation | Result | What to do |
|-----------|--------|------------|
| ATTACK tx reverts | Nothing changed | Retry; check gas / sim |
| ATTACK succeeds | Vault shares + Morpho debt | Normal. FEED when ready, or hold shares |
| FEED tx reverts | Shares + debt unchanged | Retry FEED; funds not lost |
| FEED succeeds | ~$9M USDC on landing; debt still open | Intentional. Repay later from landing/hot |
| Need emergency unwind | Debt open, want RSS back | `FireRecoverElephant` with USDC to repay |

You only owe a loan if ATTACK **fully succeeded**. Then you also **have** the matching vault shares (or, after FEED, the USDC on landing).

### Ladder (required discipline before $9M)

1. **PREP** seeder + recoverer (no borrow)
2. **Simulate** ATTACK on fork at full size
3. **Live micro ATTACK** e.g. `$1,000` - prove end state
4. **Live micro FEED** that size to landing
5. **Only then** King go on full `$9M`

### Pre-flight before any live ATTACK
- Hot ETH ≥ **0.02** (gas)
- Fork sim PASS for the exact size
- Recoverer deployed + Morpho-authorized
- Landing address verified with a small test send

---

## Why this works now (not before)

- **Before:** $9M sat in V1 yRSS at ~100% util - **trapped**.
- **Now:** V2 + live-proven `forceDeallocate` → King **can access and move** vault USDC even at full util.
- Still a **loan against King RSS**. Control problem is solved.

## Phases

### Phase 0 - PREP

```bash
PRIVATE_KEY=<hot> forge script script/FireWarElephant.s.sol --rpc-url $RPC --broadcast -vvvv
PRIVATE_KEY=<hot> forge script script/FireRecoverElephant.s.sol --rpc-url $RPC --broadcast -vvvv
```

### Phase 1 - ATTACK (King go)

```bash
KING_GO=1 FIRE_ATTACK=1 BORROW_USDC=9000000000000 SEEDER=<addr> PRIVATE_KEY=<hot> \
  forge script script/FireWarElephant.s.sol --rpc-url $RPC --broadcast -vvvv
```

Micro first: `BORROW_USDC=1000000000` ($1,000).

### Phase 2 - FEED (King go)

```bash
KING_GO=1 FIRE_FEED=1 PRIVATE_KEY=<hot> \
  forge script script/FireFeedWarElephant.s.sol --rpc-url $RPC --broadcast -vvvv
```

### Phase 3 - RECOVER (optional, King go)

```bash
KING_GO=1 FIRE_RECOVER=1 RECOVERER=<addr> PRIVATE_KEY=<hot> \
  forge script script/FireRecoverElephant.s.sol --rpc-url $RPC --broadcast -vvvv
```

## Gates

| Env | Action |
|-----|--------|
| *(none)* | PREP only |
| `KING_GO=1 FIRE_ATTACK=1` | ATTACK |
| `KING_GO=1 FIRE_FEED=1` | FEED |
| `KING_GO=1 FIRE_RECOVER=1` | Repay + free RSS |

## Scripts

| File | Role |
|------|------|
| `src/CrownSelfSeedV2.sol` | Atomic attack + recoverer |
| `script/FireWarElephant.s.sol` | Prep + gated attack |
| `script/FireFeedWarElephant.s.sol` | Gated feed to landing |
| `script/FireRecoverElephant.s.sol` | Gated repay + free RSS |

**War elephant ready. Ladder first. Full $9M on King's go only.**

See also: `AIRTIGHT-LAYER.md` (theft / MEV / custom-code harden).
