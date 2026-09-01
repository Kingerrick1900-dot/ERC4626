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

See `king-pod/broadcast/FirePrimeBrokerage.s.sol/8453/run-latest.json` for full hashes.

## Live checks

```text
armed()     = false
lltv()      = 5e17 (50%)
floatUsd8() = 2200000
```

## Next (King only — still disarmed)

1. KEEP / allocate 1B eUSD per SAFE split
2. Seed LitePSM 400M + 7683 fill buffer
3. Sell ~10M eUSD @10% → USDC idle into credit
4. Optional `kingEmergencyDraw(≤2e6)` once cash is in credit
5. `setArmed(true)` → draw with total debt ≤ $11M

**SECURITY:** Key was pasted in chat — **rotate HOT after ops.** Never commit keys.
