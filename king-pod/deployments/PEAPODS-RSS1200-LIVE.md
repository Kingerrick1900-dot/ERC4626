# Peapods RSS/$1200 self-lend — Phase 1

**King GO** — retarget live ELE Peapods L1–L7 stack to RSS at **$1200/RSS**. Base 8453.

## Playbook (L1–L7)

| Step | Peapods | Kingdom RSS/$1200 |
|--|--|--|
| L1 | Flash pairing asset | Morpho flash **USDC** (`ASK_USDC`, default **$1M**) |
| L2 | Supply → receipt | **fUSDC** vault deposit |
| L3 | Wrap TKN + LP receipt | **pRSS** wrap (1:1, 18dp) + UniV2 **pRSS/fUSDC** LP |
| L5 | LP as collateral | `CrownPeapodsPair.supplyCollateral` |
| L6 | Borrow pairing asset | Borrow USDC to seeder |
| L7 | Repay flash | Flash debt **$0** |

**Result:** fUSDC vault **100% util** (PoD). LP arb surface live. Matched PoD ≠ Landing payroll by itself.

## Ratio math

RSS is **18dp**, priced **$1200/RSS**. Legs must satisfy exact equality:

```
usdcAmt = rssTokens * 1200 * 1e6
rssAmt  = rssTokens * 1e18
check:   rssAmt * 1200 * 1e6 == usdcAmt * 1e18
```

Use whole **RSS tokens** (`ASK_RSS`) — arbitrary USDC amounts truncate and revert.

| ASK_RSS | USDC flash/borrow |
|--|--|
| 584 | **$700,800** |
| 834 | **$1,000,800** (default) |

Hot needs **≥ rssAmt** free RSS and Morpho flash pool **≥ usdcAmt**.

## Fire

```bash
cd king-pod
KING_GO=1 FIRE_PEAPODS=1 ASK_RSS=834 \
  forge script script/FirePeapodsRss1200.s.sol:FirePeapodsRss1200 \
  --rpc-url https://mainnet.base.org --broadcast -vvv
```

Prep-only (deploy stack, no `selfLend`):

```bash
KING_GO=1 forge script script/FirePeapodsRss1200.s.sol:FirePeapodsRss1200 \
  --rpc-url https://mainnet.base.org -vvv
```

Reuse deployed pieces via env: `PRSS`, `FUSDC`, `PAIR`, `SEEDER`.

## Fork test

```bash
forge test --match-contract PeapodsRss1200ForkTest -vvv --fork-url https://mainnet.base.org
```

## ELE reference (already live)

| Piece | Address |
|--|--|
| pELE | `0xf2F808e3BEd62e4CbBB2c64e455641cbf7cED8F5` |
| fUSDC (ELE leg) | `0x86bEB1cbeB7b352aB81Fae8Ced01AAd18183a3E8` |
| ELE seeder | `0x5f542322668A3D615e2c662E16133AB40714BD2A` |
| `selfLend` tx | [`0xd3954b85…`](https://basescan.org/tx/0xd3954b85c4cc0800857a21def11d5b681748ba89206bbf16409b1bb1b7e84962) |

RSS/$1200 stack addresses filled after first broadcast.

## Next (Phase 2+)

After PoD lights: arm **RSS/$1200** on yRSS (`ArmYrss1200`), draw idle via PA/reallocate, `borrowIdle(700k)` → Landing.
