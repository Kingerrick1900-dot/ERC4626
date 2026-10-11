# FIRE — CrownDeepPull (Kingdom-owned eUSD/USDC depth)

**Mode:** FIRE · executed on Base  
**Side:** King  
**Pool:** Uni V3 eUSD/USDC fee 500 `0x96D0022c7a65EE7D1819D9f48C48E4f90d91a666`

---

## Live

| | |
|--|--|
| **CrownDeepPull** | `0xDDe33827dbd0aC5Ed1a8A68eE5D95c829902679A` |
| LP NFT (HOT) | tokenId **6132296** |
| eUSD minter | DeepPull = true |
| yRSS inventory gate | on |

Broadcast: `broadcast/FireDeepPull.s.sol/8453/run-latest.json`

---

## What fired

1. Deploy `CrownDeepPull`
2. `setMinter(DeepPull, true)` on Kingdom eUSD
3. `seed()` — mint eUSD against yRSS inventory gate + pair Kingdom USDC into Uni V3
4. LP NFT minted to HOT — Kingdom-owned depth

Flash path `deepPull()` is wired: Balancer flash → mint eUSD → mint LP → repay from HOT USDC (`REPAY_SOURCE=HOT USDC`). Net pool USDC = Kingdom-committed USDC (flash does not print permanent USDC).

---

## Flywheel

```
DeepPull seeds Uni bid/ask
→ CrownLiquidityRestore.swap leg clears at size
→ remainder USDC → HOT
→ next seed adds depth
```

Restore: `0x40b3F13ecbd1A36B447175Aa7719bc220dfba19A`

```
DEEP_PULL=0xDDe33827dbd0aC5Ed1a8A68eE5D95c829902679A
LP=6132296
RESTORE=0x40b3F13ecbd1A36B447175Aa7719bc220dfba19A
NEXT=size seed / restore when Morpho idle or more USDC commits
```
