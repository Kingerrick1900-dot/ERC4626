# FIRE — ZK Borrow Port (Base · Polygon · Scroll)

**Mode:** FIRE · executed  
**Order:** Refresh proof → Port Gate+Credit → Verify `isProven` → Borrow to HOT  
**Doctrine:** ZK proof is the collateral. Credit instrument on all three chains. Real USDC to HOT.

---

## 1) Base proof refreshed

| Action | Result |
|--|--|
| `FireZkAttestRefreshCast` borders | Base epoch **15** · Poly **6** · Scroll **8** · all `bordersSecure=true` |
| WalletGate `submitProof` (HOT) | [`0xdb05d91b…5bcf`](https://basescan.org/tx/0xdb05d91b4155f0d98d2d78d9008cd4186b99a46f730c37e6a14884d5b8825bcf) |
| Legacy Gate `0xFfC9…f579` | **`isProven(HOT)=true`** · thr $700k |

---

## 2) Port live addresses

| Chain | WalletGate | Credit | Pay token | Verifier |
|--|--|--|--|--|
| **Base** 8453 | `0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091` (+ legacy `0xFfC9…f579`) | `0x75279D46F0dA7f91D5283687C1D0a6EF86992e09` | USDC `0x8335…2913` | `0x6778…1AAE` |
| **Polygon** 137 | `0xd0c8740A4E82c4F23382429f67D8e1A1Af7627Da` | `0xe8EF9f6d240A2B8eF4D4e24Ffc360d6E4C703B18` | USDC `0x3c49…3359` | `0x883c…d0a8` |
| **Scroll** 534352 | `0xBCFE1408507241531A3F6a39F9E356cdBa5D2575` | `0x869EFE268515F757126f1e76F5e90164E9f84413` | axlUSDC `0xEB46…5215` | `0x058b…7403` |

Broadcasts:
- `broadcast/FireZkBorrowAttestPort.s.sol/8453/run-latest.json`
- `broadcast/FireZkBorrowAttestPort.s.sol/137/run-latest.json`
- `broadcast/FireZkBorrowAttestPort.s.sol/534352/run-latest.json`

---

## 3) Verify — `isProven(HOT)=true` on all three

| Chain | Gate | isProven |
|--|--|--|
| Base (legacy) | `0xFfC9…f579` | **true** |
| Base (port) | `0x3fF6…7091` | **true** |
| Polygon | `0xd0c8…27Da` | **true** |
| Scroll | `0xBCFE…2575` | **true** |

---

## 4) Borrow → HOT

| Chain | Seed source | Borrowed to HOT | Tx |
|--|--|--|--|
| **Polygon** | ColdBuffer → desk → Credit **$0.49** | **490000** USDC (6dp) @ HOT | [`0xb71188a9…63a8`](https://polygonscan.com/tx/0xb71188a968cdf8606715bd29912ba749c992345825c47f001d6573c9024863a8) |
| **Base** | HOT dust **10278** → Credit → borrow back | **10278** USDC debt (net wallet recycle) | port broadcast 8453 |
| **Scroll** | axlUSDC bal **0** | **0** — Credit live, pool empty (no Circle USDC on Scroll at probe) | port OK |

Credit king = HOT · operator = chain deployer · `operatorBorrowTo(HOT, max)`.

---

## Honest pool depth

ZK unlocks borrow **≤ 70% × $700k threshold** when the Credit pool is funded.  
Kingdom-controlled USDC available to seed at fire time was **dust** (Poly cold $0.49 · Base ~$0.01).  
Instrument is live on all three; scale = seed more USDC into Credit, then draw again against the same proven gate.

---

## Identity

```
PROOF=refreshed isProven=true ×3
PORT=Gate+Credit Base/Polygon/Scroll LIVE
BORROW=poly $0.49 USDC → HOT · base dust recycle · scroll pool empty
SCOREBOARD=real USDC at HOT (poly 490000 + base dust)
NO_LENDER_EXTERNAL=Kingdom Credit only
```
