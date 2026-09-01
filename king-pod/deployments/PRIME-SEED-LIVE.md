# PRIME SEED — LIVE (7683 pipe armed)

**Status:** SEEDED · order open · **waiting solver fill**  
**Block:** ~50719308 · **Chain:** Base 8453

## What fired (King GO)

| Step | Tx | Result |
|--|--|--|
| `setFees(1000,10)` — **10% discount** | [`0x0c0f5dac…0959`](https://basescan.org/tx/0x0c0f5dacfa9bed953bf9bd953e0f40b284811ff64bbd0f05166c30b1d9230959) | maxDiscountBps=1000 |
| LitePSM seed **2M eUSD** | [`0xd1b96639…82f6`](https://basescan.org/tx/0xd1b966393fb888ed83d5c16be3d678dc240f42d8ead27051824a4fe6517b82f6) | door open |
| Fill buffer **5M eUSD** | [`0x1e9e546b…5f15`](https://basescan.org/tx/0x1e9e546b96b7bc488cb2d09db924f0abcff84e246d69fb438c3f2e383ad05f15) | inventory locked |
| **openOrder** 5M @ $4.5M max | [`0xdb9345bb…13aa`](https://basescan.org/tx/0xdb9345bbf5742b88aeb94a1ab918f2416de82c10f8329ba7e23b722b4c9813aa) | status=open |
| **lockGusd 1B** | [`0x52d533b1…5d45`](https://basescan.org/tx/0x52d533b1e9be96efe3e9f190e09362714933f0f8fe46ccfcd9cd10e7d5fa5d45) | $11M debt cap live |

## Order (solver fill this)

```text
orderId = 0x2b75086050a42e49192593ad9d97cec9a7f0e829cbf514fce982bf0940a9b88c
Fill:    0x4C021c77633e9441be218d2A27a4B40c1Bd720Ab
Pay:     ≥ $4,500,000 USDC (10% discount on 5M eUSD)
Gets:    5,000,000 eUSD → HOT
USDC →  CrownPrimeCredit idle (then draw)
```

## Live checks

```text
Fill eUSD buffer     = 5,000,000 eUSD
LitePSM buffer       = 2,000,000 eUSD
Credit USDC idle     = 0 (until fill)
gusdLocked           = 1,000,000,000 gUSD
maxDebtUsd6          = 11,000,000 USDC
router.armed         = false
```

## Post-fill (same block)

1. `USDCBorrowRouter.setArmed(true)`
2. `draw(4_500_000e6, Landing)` or `kingEmergencyDraw` if pre-armed path
3. `SelfRepayingTreasury.sweep` as fees land

## Gas note

Base gas ≈ **$0.01 total** for seed txs — not material vs $4.5M. HOT is EIP-7702; txs sent **one-at-a-time** (ops rule). Not gasless, but negligible.

**Rotate HOT key** — was used in chat.

## Script replay

```bash
PRIVATE_KEY=0x… BASE_RPC_URL=https://mainnet.base.org \
  bash king-pod/script/FireSeed7683Cast.sh
```
