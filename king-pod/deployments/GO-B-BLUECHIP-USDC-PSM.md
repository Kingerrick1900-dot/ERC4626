# GO-B — Bluechip loan → USDC borrow → PSM seed

**Status:** chassis + fork path · **live blocked on WETH lender inventory**

## Play

1. **Loan WETH against free RSS** via `CrownRssWethDesk` (loan, don’t sell).
2. **Post WETH** on Morpho WETH/USDC `0x8793…1bda` (LLTV 86%, idle ~$8M+).
3. **Borrow USDC** → `MultiPSM.seed` `0xF733…F987`.
4. **Redeem eUSD → USDC** on Landing (spend rail opens).

RSS Morpho books stay untouched.

## Size (WETH ≈ $1,907)

| USDC seed target | WETH coll @ ~75% of LLTV band |
|--|--|
| $70k (first slice) | ~50 WETH |
| $700k (full ask) | ~427 WETH |

## Board blocker

Kingdom free bluechip ≈ **$0**. On-chain RSS→WETH Morpho idle ≈ **dust**.  
**Need:** WETH lender to `fund()` the desk (or WETH delivered to hot under RSS escrow).

## Fork prove

```bash
forge test --match-contract GobBluechipUsdcPsmFork --fork-url $BASE_RPC_URL -vv
```

## Live (after WETH on hot)

```bash
WETH_IN=50000000000000000000 USDC_OUT=70000000000 \
  forge script script/FireGobSeedPsm.s.sol:FireGobSeedPsm \
  --rpc-url $BASE_RPC_URL --broadcast -vvvv
```
