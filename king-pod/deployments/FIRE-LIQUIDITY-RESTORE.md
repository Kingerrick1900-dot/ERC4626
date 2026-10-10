# FIRE — CrownLiquidityRestore (swap-leg close)

**Mode:** FIRE · executed on Base  
**Side:** King  
**Pattern:** Morpho flash → repay → withdraw eUSD → Uni V3 eUSD→USDC → repay flash → remainder HOT  
**REPAY_SOURCE:** `UniV3.exactInputSingle(eUSD→USDC, fee=500)`

---

## Live

| | |
|--|--|
| **CrownLiquidityRestore** | `0x40b3F13ecbd1A36B447175Aa7719bc220dfba19A` |
| Deploy | [`0x0ece398f…b9bf`](https://basescan.org/tx/0x0ece398fbfff675cb4d097eee82c67f432834b078fa091b6e11a16db14fbb9bf) |
| Auth HOT→restore | [`0x26f9fded…e0d5`](https://basescan.org/tx/0x26f9fdedcbf1f37ee04140de8870cc1a7fe08a33da81744f3b91915096dae0d5) |
| **restore()** | [`0x1d53234e…eced`](https://basescan.org/tx/0x1d53234eafb87688df4b10ae0c7ea94737046849f8d1e55db19de4862157eced) |
| Synth Morpho book (HOT) | closed (supply/borrow/coll = 0) |

---

## Callback (wired and fired)

```
1. flashLoan(USDC)
2. repay Morpho debt
3. withdrawCollateral eUSD
4. Uni V3 swap eUSD → USDC   ← SWAP LEG
5. repay flash (fee 0)
6. leftover → HOT
```

Scale gate inside `restore()`: QuoterV2 must clear `debt + minToHot` or **`Depth()`**.  
That gate is the pool’s USDC bid — fill the eUSD/USDC book (or free yRSS / open a funded Morpho door) and the same contract draws size. No new invention required.

---

## Artifacts

- `src/CrownLiquidityRestore.sol`
- `script/FireLiquidityRestore.s.sol`
- `broadcast/FireLiquidityRestore.s.sol/8453/run-latest.json`

```
RESTORE=0x40b3F13ecbd1A36B447175Aa7719bc220dfba19A
LEG=UniV3 eUSD→USDC
FIRED=restore()
BOOK=synth closed
NEXT=fund the repay side (Uni bid / Morpho idle / yRSS unlock) → call restore at size
```
