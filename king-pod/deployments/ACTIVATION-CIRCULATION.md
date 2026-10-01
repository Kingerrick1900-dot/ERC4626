# ACTIVATION — Circulation proven (no outreach)

**Doctrine:** The Kingdom does not ask. The Kingdom demonstrates.  
**No new contracts. No emails. Existing rails only.**

---

## 1) Base — Kingdom = first lender + first borrower

| Step | Result | Tx |
|--|--|--|
| HOT USDC → ySYNTH | **$0.330485** deposited | in `FireActivateCirculation` broadcast |
| eUSD collateral posted | **10 eUSD** on market `0x08039ffa…3fcd` | same |
| Borrow USDC → HOT | **$1.317180** | same |

Live after fire:

| Meter | Value |
|--|--|
| ySYNTH `totalAssets` | **$1.330485** |
| HOT USDC | **$1.317180** |
| HOT Morpho collat | 10 eUSD |
| Market util | ~99% ($1.317180 borrowed / $1.330485 supplied) |

Script: `script/FireActivateCirculation.s.sol`  
Broadcast: `broadcast/FireActivateCirculation.s.sol/8453/run-latest.json`

---

## 2) Polygon — Royal Card / SoftPOS real tap

| Step | Result | Tx |
|--|--|--|
| registerMerchant CHINA-DESK-001 | live | [`0xf4cdf8b9…97d6`](https://polygonscan.com/tx/0xf4cdf8b9f80a4fd0acff79b5148db74cc695e88fb8a6d2f45c56258eeb4e97d6) |
| registerTerminal TERM-SOFTPOS-01 | live | [`0x3cdc8023…838d`](https://polygonscan.com/tx/0x3cdc8023edf5bf1e0cbd82aec1365c182f7c003a11174743787c1f245d0f838d) |
| micropay **1 eUSD** (payMode RoyalCard) | captured | [`0xa6d897ea…5958`](https://polygonscan.com/tx/0xa6d897ea5ca6acad4e66fb36e64c76e1e586409e1977af04d960a6bddea95958) |
| settle → desk wallet | settled | [`0x1f17f4fe…8620`](https://polygonscan.com/tx/0x1f17f4fe8d68a75d60558f6d027644fa44fa284e443687e9fedd841d01748620) |

Acquiring: `0xbb5b4439060a3f46d14826973fb30ada661ff5f0` · `totalCaptured = 1e18`

---

## Truth (no polish)

Circulation moved. Size is dust — **dollars, not millions**. The loop works on Kingdom capital. Outside fill still required to scale; that is not claimed here.

```
ACTIVATION=circulation ✓
BASE=lend→borrow ySYNTH/Morpho hotUsdc=1.317180
CHINA=1 eUSD SoftPOS micropay+settle ✓
NEXT=scale idle USDC in ySYNTH (same loop, larger size)
```
