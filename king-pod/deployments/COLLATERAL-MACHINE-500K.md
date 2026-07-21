# Collateral Machine — 500k Test (No Pocket USDC)

## LAW — Cold or revert

**If USDC does not hit Landing (cold), the entire transaction reverts.**  
No partial fill on hot. No “stuck in the machine.” `LandingMiss` kills the tx.

Checked:
- after Morpho borrow → Landing  
- mid-flash after ZK Advance  
- again after flash closes  
- USDC `rescue` can only send to Landing  

## Plain English

A Morpho flash loan is a **same-block loan**, not free money. Whatever you flash, you must return in that same transaction.

So this line is **impossible**:

> flash USDC → send it to Landing → repay the flash → keep the Landing USDC → keep all your RSS → take on no debt

Something has to pay the flash back. That payment is either:

1. **Sell RSS** for USDC in the same tx, or  
2. **Borrow USDC** against RSS (Morpho debt; RSS stays locked as collateral)

Flash is the lever. RSS is the fuel. USDC out is real only if one of those two closes the loop — **and** cold must credit or everything unwinds.

## Modes built (`CrownCollateralMachine`)

| Mode | Path | RSS | Debt | Repay source |
|------|------|-----|------|----------------|
| `borrowToLanding` | RSS → Morpho coll → borrow → Landing | Locked | Yes | *(none — spot borrow)* |
| `flashAdvanceToLanding` | flash USDC → ZK Advance → Landing → sell RSS → repay flash | Sold (fuel) | No Morpho debt | `Aero.swap(RSS→USDC)` |

## Live Base facts (why 500k reverts today)

| Gate | Reality |
|------|---------|
| Morpho flash capacity | Large (USDC on Morpho ≫ 500k) — lever OK |
| ZK Advance stock | ~700k kUSD — door OK |
| Morpho RSS market idle | ~$1 — **borrow mode reverts `NoIdle`** |
| Aero RSS/USDC pool | ~$1 USDC reserve — **flash repay reverts (depth)** |
| Quote 500k RSS → USDC | ~$0.83 |

## Fork tests

```bash
forge test --match-contract CrownCollateralMachineForkTest -vv
```

- `test_fork_borrow_500k_reverts_no_idle` — market empty  
- `test_fork_flash_advance_500k_reverts_repay_short` — pool empty  
- `test_fork_flash_advance_500k_succeeds_when_pool_deep` — seed pool on fork → **Landing +500k** proves machine

## Deployed (Base) — deploy only, no live fire

| | |
|--|--|
| **CrownCollateralMachine** | `0x27bF9A700d24cE75137A8621ebd9b5B1BB96800c` |
| Landing (immutable) | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| Live pool quote (600k RSS) | ~$0.86 — **below 500k → LIVE_FIRE blocked** |

```bash
KING_OK=1 FIRE_COLLATERAL_MACHINE=1 forge script script/FireCollateralMachine.s.sol \
  --rpc-url $BASE_RPC --broadcast --chain 8453
```

Live execute only with `LIVE_FIRE=1 KING_GO=1` **and** `POOL_DEPTH_SHORT` clear (quote ≥ 500k).

## What the Kingdom demands from the market

For the flash machine at 500k: **Aero (or other) RSS→USDC depth ≥ $500k**, *or* Morpho RSS market idle ≥ $500k for borrow mode.  
Until the market provides that depth/liquidity, the lever has nothing to push against — pocket USDC is still not required; **market depth is.**
