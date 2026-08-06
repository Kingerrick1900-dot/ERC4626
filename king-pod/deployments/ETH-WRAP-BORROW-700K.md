# ETH wrap → Morpho → Landing $700k USDC

**Solution (King order):** MorphoWethLoanProtectionPolicy wrap shape + LI.FI equity path C.  
**No WETH balance required upfront** — native ETH wraps in-tx.

## Call plan (one tx)

```text
1. WETH.deposit{value: ethIn}()          // wrap native ETH
2. WETH.approve(MORPHO, ethIn)
3. Morpho.supplyCollateral(WETH/USDC, ethIn, machine)
4. Morpho.borrow(usdcOut → Landing)
```

**Contract:** `CrownDualFlashMachine.equityEthBorrow`  
**Market:** WETH/USDC `0x8793…1bda` · LLTV 86% · idle ~$7–8M  
**Oracles / IRM:** WETH `0xFEa2…aFE4` · IRM `0x4641…2687`

## Size (WETH ≈ $1,908)

| Landing USDC | ETH equity (msg.value) | ~LTV |
|--|--|--|
| $700,000 | **500 ETH** | ~73% of LLTV band |
| $70,000 | ~50 ETH | same band |

## Fork

```bash
cd king-pod
forge test --match-test test_E_equity_eth_wrap_lands_700k -vv --fork-url https://mainnet.base.org
```

**PASS:** Landing Δ = **+$700,000 USDC** with `vm.deal(HOT, 500 ether)`.

## Live fire

```bash
cd king-pod
ETH_IN=500000000000000000000 USDC_OUT=700000000000 \
  forge script script/FireEthWrapBorrow.s.sol:FireEthWrapBorrow \
  --rpc-url https://mainnet.base.org --broadcast -vvvv
```

Reuse deployed machine: `MACHINE=0x…`  
Hot must hold `ETH_IN` (+ gas). USDC lands on `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357`.

## Notes

- Coinbase `MorphoWethLoanProtectionPolicy` is Smart-Wallet/PolicyManager scoped; hot is EOA — same wrap→supply plan is inlined here, plus borrow to Landing.
- Dual-flash modes A/B/D still net $0 / revert without equity; this is path **E** (wrap equity).
