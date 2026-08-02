# Open PA — ELE77 — LIVE

**Order:** Open PA  
**Fired:** 2026-07-28 · King PA admin on yELE + yRSS

## Kingdom doors — OPEN

| Vault | Market | maxIn | maxOut |
|--|--|--|--|
| **yELE** | ELE77 | **$28.7M** | **$28.7M** |
| **yELE** | WETH/USDC | **$28.7M** | **$28.7M** (was **0**) |
| **yRSS** | ELE77 | **$28.7M** | **$28.7M** (market **enabled**) |
| **yRSS** | WETH/USDC | **$28.7M** | **$28.7M** |
| **yRSS** | cbBTC/USDC | **$28.7M** | **$28.7M** |

yRSS supply queue: cbBTC → WETH → RSS77 → ELE77.

## Fix unlocked

yELE previously had ELE77 `maxIn=$700k` but **WETH `maxOut=0`** — PA could not source. Both legs now open at headroom size.

## Foreign doors — still closed (not King-admin)

| Vault | ELE77 maxIn |
|--|--|
| Gauntlet USDC Prime | **0** |
| Steakhouse Prime / USDC / HY | **0** |

Those admins are external. Kingdom PA cannot set them.

## Vault assets now

yELE / yRSS totalAssets ≈ dust. Caps are open; deposits (or foreign curator enable) still needed before `reallocateTo` + `$500k` borrow fills.

## Txs

| Step | Hash |
|--|--|
| yELE `setFlowCaps` | [`0x649122ba…f12d`](https://basescan.org/tx/0x649122bab0e83e3dc44061a3d486b849875363a4e925a43c349d72342374f12d) |
| yRSS `submitCap` ELE77 | [`0x3a3f9f7f…ca46`](https://basescan.org/tx/0x3a3f9f7f83e45cacbcbc7d7bfe7608b029b47366e16be50ab070b31067baca46) |
| yRSS `acceptCap` ELE77 | [`0x7ec87cb9…8307`](https://basescan.org/tx/0x7ec87cb93b092ab0300df9dfc7d05f4537035fa576eb0f8a8110f7d87a2c8307) |
| yRSS `setSupplyQueue` | [`0x7c6657b0…80b1`](https://basescan.org/tx/0x7c6657b0b969ddbaee5a85e4a67d34c5d3321d4a9a794d8d8d39328c545c80b1) |
| yRSS `setFlowCaps` | [`0xd1021e9d…ae47`](https://basescan.org/tx/0xd1021e9da2891aa0f9ffce19de416dfc2e613922e704922c72a0cfe5d017ae47) |

Broadcast: `king-pod/broadcast/FireOpenPaEle77.s.sol/8453/run-latest.json`  
Status: `OPEN_PA_ELE77_OK`
