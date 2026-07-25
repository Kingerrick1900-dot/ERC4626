# LeverageExtractor — what works on Base (live)

## Engine (live)

| Meter | Value |
|--|--|
| ELE coll | ~**100.00M** |
| Morpho debt | ~**$50.00M** |
| LLTV headroom | ~**$27M** unclaimed |
| Landing USDC | ~**$59.38** |
| ELE/USDC idle | ~**$1** buffer |
| Extractor (armed) | `0x3734658F1b86bD0EE86b5ac15015fE98B7Ad8947` |
| Deploy tx | [`0x…`](https://basescan.org) — see `broadcast/FireLeverageExtract.s.sol/8453/run-latest.json` |

Headroom needs **foreign idle** into ELE/USDC (PA `maxIn` on a funded vault), then borrow.  
Live arm: foreign `maxIn=0`, yELE WETH disabled → `ARM_ONLY=1` (no fake $700k).

## Correct ship

- `CrownLeverageExtractor` — Morpho Blue + PA `reallocateTo(vault, Withdrawal[], ELE params)` + borrow → Landing
- Hard revert `PA_NO_LIQ` if idle does not rise by `pull` (kills yELE maxIn trap)
- Fork: `LeverageExtractForkTest` (3/3)

```bash
# Arm extractor on-chain (authorize; wait for PA/idle)
KING_GO=1 FIRE_LEVERAGE=1 ARM_ONLY=1 forge script script/FireLeverageExtract.s.sol:FireLeverageExtract \
  --rpc-url $RPC_URL --broadcast --slow --private-key $PRIVATE_KEY

# Fire when foreign maxIn > 0
KING_GO=1 FIRE_LEVERAGE=1 PA_VAULT=0x… PULL_USDC=700000000000 EXTRACTOR=0x… \
  forge script script/FireLeverageExtract.s.sol:FireLeverageExtract \
  --rpc-url $RPC_URL --broadcast --slow --private-key $PRIVATE_KEY
```

## DeepSeek 5-step plan vs chain

| Step | Claim | Live fact |
|--|--|--|
| 1 | WETH/USDC idle confirmed | **Blue market** idle ≈ **$7.5M** — owned by *other* suppliers, not yELE |
| 2 | ELE maxIn $700k open | yELE PA `flowCaps.maxIn` = **$700k** — permission only |
| 3–5 | PA move WETH→ELE → borrow $700k → King | **Reverts today** — yELE has **$0** in WETH/USDC |

### yELE (curator = hot) right now

| Meter | Value |
|--|--|
| `totalAssets` | ≈ **$50** |
| ELE/USDC config | enabled · cap $14M |
| WETH/USDC config | **disabled** · pending cap $50M · `validAt` `1785092927` |
| Morpho supply on WETH/USDC | **0** |
| Morpho supply on ELE/USDC | dust (~$50) |
| PA fee | 0 |

`maxIn` does not mint vault liquidity. PA can only move **that vault’s** Morpho supply.

## API corrections (DeepSeek draft → Morpho)

Wrong:

```solidity
publicAllocator.reallocateTo(address(vault), eleMarketParams.loanToken, amount);
// and MetaMorpho.MarketAllocation { address market; uint256 supply; }
```

Correct Public Allocator (Base `0xA090dD1a701408Df1d4d0B85b716c87565f90467`):

```solidity
struct Withdrawal { MarketParams marketParams; uint128 amount; }
function reallocateTo(
    address vault,
    Withdrawal[] calldata withdrawals,   // FROM markets (e.g. WETH/USDC params)
    MarketParams calldata supplyMarketParams  // TO = ELE/USDC params
) external payable;
```

Correct MetaMorpho `reallocate` (allocator-only):

```solidity
struct MarketAllocation { MarketParams marketParams; uint256 assets; }
```

Morpho Blue `supplyCollateral(mp, assets, onBehalf, data)` — 4th arg is `bytes data`, not receiver.

## Working extractor in repo

`CrownLeverageExtractor` + `FireLeverageExtract`:

```bash
# Idle-only draw (no PA)
KING_GO=1 FIRE_LEVERAGE=1 forge script script/FireLeverageExtract.s.sol:FireLeverageExtract \
  --rpc-url $RPC_URL --broadcast --slow --private-key $PRIVATE_KEY

# PA path when a vault has maxIn>0 AND source-market supply
KING_GO=1 FIRE_LEVERAGE=1 PA_VAULT=0x… PULL_USDC=700000000000 \
  forge script script/FireLeverageExtract.s.sol:FireLeverageExtract \
  --rpc-url $RPC_URL --broadcast --slow --private-key $PRIVATE_KEY
```

Receiver: Landing `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357`.

## How $700k (or more) actually lands

King already has ~**100M ELE** coll and ~**$50M** engine debt → ~**$27M** LLTV headroom.

Need **foreign USDC** into ELE/USDC idle, then borrow:

1. **Curator PA** — Gauntlet / Steak / Moonwell set `flowCaps.maxIn ≥ $700k` on market `0xa4ec5271…da53fc`, then `FIRE_LEVERAGE` + `PA_VAULT` + `PULL_USDC`
2. **After yELE WETH cap accept** (~unlock) — still need real USDC deposited/allocated into yELE’s WETH market before PA can pull it to ELE
3. **Direct supply** into ELE/USDC or ZK credit `0xc415…d936`

Until one of those has **vault-owned** (or market) idle, `extract(700_000e6)` cannot succeed.
