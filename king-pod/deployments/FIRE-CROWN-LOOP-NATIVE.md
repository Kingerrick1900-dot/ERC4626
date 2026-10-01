# FIRE — CrownLoopNative (Atomic Morpho flash self-seed)

**Mode:** FIRE · executed on Base  
**Doctrine:** Stop thinking about $1M outside. One atomic transaction. The $1 is the seed. The flash is the multiplier.  
**Precedent:** Ethena / Falcon Morpho loop — flash depth → collateral → borrow → repay in one block.

---

## LIVE

| Item | Value |
|--|--|
| **CrownLoopNative** | [`0xedBb3bCF9E31B37C748AeAaB6d86Cefe759F5D3a`](https://basescan.org/address/0xedBb3bCF9E31B37C748AeAaB6d86Cefe759F5D3a) |
| Market | `0x08039ffa…3fcd` eUSD→USDC · LLTV **86%** |
| Morpho Blue | `0xBBBB…FFCb` (flash fee = 0) |
| King / HOT | `0x6708…a7d1` |
| **fires** | **2** |
| **totalFlashed** | **$1,100,000** USDC |
| **totalCollateralPosted** | **≈1,304,651 eUSD** |

### Mechanism (one tx)

```
1. Pull eUSD from king → supplyCollateral on Morpho (onBehalf king)
2. Morpho.flashLoan(USDC, flashUsdc)
3. onMorphoFlashLoan:
     supply flashed USDC → market depth (onBehalf king)
     borrow same USDC against eUSD coll → this
     repay flash (fee 0)
4. End: king Morpho supply≈borrow≈flash; eUSD coll posted; wallet USDC unchanged
```

No outside lender. No waiting. Cap is Morpho flash liquidity + king's eUSD inventory + vault supply cap ($200M).

---

## Fires

| # | Flash | eUSD coll | Tx | Block |
|--|--|--|--|--|
| Deploy | — | — | [`0xf09cd911…2c5a`](https://basescan.org/tx/0xf09cd911c25e2a7a0d7aea78c41d6e045c4e0861902725f75448d23dd8aa2c5a) | 52023674 |
| Auth + approve | — | — | [`0x4fbaee44…ecbb`](https://basescan.org/tx/0x4fbaee44cdf8d2af6853ab2caa0a2f890c621b859d9d2dfc655d75e9e419ecbb) · [`0x7e1fa1be…0aba`](https://basescan.org/tx/0x7e1fa1be6c971a2897bfb74b1867af1e742a06e05249fba8bdd628444a190aba) | 52023674 |
| **1** | **$100,000** | 118,604.65 | [`0x1e16d0ec…1837`](https://basescan.org/tx/0x1e16d0eca242e76bd47352428e16d5a12b098dcf1f82a0aa81d067b160c91837) | 52023674 |
| **2** | **$1,000,000** | 1,186,046.51 | [`0x6a4f30a7…f303`](https://basescan.org/tx/0x6a4f30a70b51c80a32bb7fbff518755673c88babc0e62143db44383cefd8f303) | 52023680 |

Scripts: `script/FireCrownLoopNative.s.sol` (deploy+fire1) · `script/FireCrownLoopNativeResume.s.sol` (scale)

---

## Scoreboard (live after fire2)

| Meter | Value |
|--|--|
| Market supply | **≈ $1,100,001.34** |
| Market borrow | **≈ $1,100,001.32** |
| HOT Morpho collateral | **≈ 1,304,661 eUSD** (10 activation + 1,304,651 loop) |
| HOT wallet USDC | **$1.317180** (unchanged — flash closes) |
| ySYNTH `totalAssets` | **$1.330491** (dust seed; loop supplies Morpho directly, not the vault) |

```bash
LOOP=0xedBb3bCF9E31B37C748AeAaB6d86Cefe759F5D3a
cast call $LOOP "fires()(uint256)" --rpc-url $BASE_RPC
cast call $LOOP "totalFlashed()(uint256)" --rpc-url $BASE_RPC
# → 2 · 1100000000000
```

---

## Truth (no polish)

The atomic loop **works**. $1.1M Morpho depth was created in two taps from Kingdom eUSD + Morpho flash — not from a $1M wire.

**What this is not:** spendable HOT USDC did not rise. Flash supplies and borrows cancel at close. Real USDC out still needs external idle in ySYNTH / Exit inventory / a buyer on the other side of the borrow.

**What this is:** the machine that turns eUSD inventory into market size in one block. Scale = `FLASH_USDC` + eUSD coll @ 86% LTV.

```
FIRE=crown-loop-native ✓
LOOP=0xedBb3bCF…5D3a fires=2 totalFlashed=$1.1M
MARKET≈$1.1M supply/borrow · HOT coll≈1.30M eUSD
HOT_USDC=$1.317180 (flash-closed · honest)
NEXT=scale FLASH_USDC via Resume · or fill ySYNTH idle for true USDC-out
```
