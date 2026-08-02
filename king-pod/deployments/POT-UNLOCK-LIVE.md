# Pot unlock LIVE — debt repay → withdraw → flash close

**Helper:** `0x936678F62Fd1D6ea6B0Fd446D9E6EF7dc625e220` (`CrownDebtRepayUnlock`)  
**Unlock tx:** [`0x37e7fd7b…46eee3`](https://basescan.org/tx/0x37e7fd7b3951c46a7395ce317e5764a143b4601d10314cb5e7ac73cb5246eee3)

## Sequence (what actually ran)

1. Morpho flash USDC (~$700,048)  
2. Repay king debt on ELE/USDC **77%**  
3. `yELE-K.withdraw` exact flash size (not full-share redeem — that hits `NotEnoughLiquidity`)  
4. Morpho pulls flash via `transferFrom` (fee = 0)

## Result

| | Before | After |
|--|--|--|
| yELE-K claim | ~$700,064 | ~**$15.82** residual |
| Hot USDC | ~$60.38 | ~$60.38 (**Δ ≈ $0**) |
| Share trap | locked | **cleared** (dust left) |

Matched book ⇒ unlock is deleverage, not mint. Ops dollars stay the wallet USDC + ELE/USDC pool rail.

## Draft bugs rejected

External `DebtRepayUnlock` draft was wrong for Morpho Blue:

- Callback is `onMorphoFlashLoan(uint256 assets, bytes data)` — **no fee arg**
- `repay` 5th arg is `bytes data`, not a receiver
- Flash repay = **approve** Morpho (pull after callback), not `transfer` to Morpho
- Full `redeem(all shares)` reverts `NotEnoughLiquidity` on this book
