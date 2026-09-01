# PRIME BROKERAGE — LIVE ON BASE (8453)

**Status:** DEPLOYED · router **disarmed** · King GO fired  
**Deployer / HOT:** `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1`  
**Params live:** `floatUsd8 = 2.2e6` · `lltv = 50%` · max debt `$11M` · emergency cap `$2M`

## Addresses

| Contract | Address |
|--|--|
| CrownBoundLandingCollateral | [`0x99bE1Ec7Dba573da84cF42663B60A27108B6c3e8`](https://basescan.org/address/0x99bE1Ec7Dba573da84cF42663B60A27108B6c3e8) |
| CrownPrimeCredit | [`0xc184A1d2486a24FAb9eB51764c9CF193AE3e6D15`](https://basescan.org/address/0xc184A1d2486a24FAb9eB51764c9CF193AE3e6D15) |
| CrownLitePsm | [`0xC28E7faA9aBb9E6d9627C612F0fb1Bec66E99F6B`](https://basescan.org/address/0xC28E7faA9aBb9E6d9627C612F0fb1Bec66E99F6B) |
| CrownPrime7683Fill | [`0x4C021c77633e9441be218d2A27a4B40c1Bd720Ab`](https://basescan.org/address/0x4C021c77633e9441be218d2A27a4B40c1Bd720Ab) |
| USDCBorrowRouter | [`0xA4E04b3160c7ed3cF1c4341DD2f67a06eFF85b6c`](https://basescan.org/address/0xA4E04b3160c7ed3cF1c4341DD2f67a06eFF85b6c) |
| SelfRepayingTreasury | [`0xA1215D21eBC646F609d2CcAAc0cD4E00bF0ebd97`](https://basescan.org/address/0xA1215D21eBC646F609d2CcAAc0cD4E00bF0ebd97) |

## Create txs

| Contract | Tx |
|--|--|
| BoundLandingCollateral | [0x86fb…3555](https://basescan.org/tx/0x86fbaf0ba5b0aa04df0dfff0dea9eefd80b2c68556deb049213a2a9a74bf3555) |
| PrimeCredit | [0x46c8…4c9e](https://basescan.org/tx/0x46c85a994bfc4b2ed2985db77ab966cf6a1d1401a9e197d33fb4c668d1204c9e) |
| LitePsm | [0xb352…ae10](https://basescan.org/tx/0xb3526de7c16528ea35afe470e49faa235def2f506957852895a9daf8f4cbae10) |
| SelfRepayingTreasury | [0xeeee…5d01](https://basescan.org/tx/0xeeee3e6a8b6d769eb10d2561666515f2494926d15e8552ba493abfc33bf85d01) |
| Prime7683Fill | [0x8770…6f1e](https://basescan.org/tx/0x8770a84bae0a0162b3c2693f2c43c63ec8bbffd849234019ca8ca749b93f6f1e) |
| USDCBorrowRouter | [0x995d…2cc0](https://basescan.org/tx/0x995de7be2014cbdb75063e7374a91eca67b57dadc329ff6d1fa5df277b522cc0) |

Broadcast artifact: `king-pod/broadcast/FirePrimeBrokerage.s.sol/8453/run-latest.json`

## Live checks (post-deploy)

```text
armed()     = false
lltv()      = 5e17 (50%)
floatUsd8() = 2200000
```

## Next (King only — still disarmed)

1. KEEP / mint 1B eUSD allocation per SAFE split
2. Seed LitePSM 400M + 7683 fill buffer
3. Sell ~10M eUSD @10% → USDC idle into credit
4. Optional `kingEmergencyDraw(≤2e6)` once cash is in credit
5. `setArmed(true)` → draw with total debt ≤ $11M

**SECURITY:** Key was pasted in chat — **rotate HOT key after ops.** Never commit keys.
