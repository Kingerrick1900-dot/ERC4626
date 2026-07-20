# Engineering brief — Whale USDC depth (Base)

**Audience:** Kingdom eng team  
**Goal:** Move ops funding off empty RSS/USDC book onto Morpho markets with **live USDC idle**.  
**Chain:** Base (`8453`) · Morpho Blue `0xBBBB…FFCb` · USDC `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`

---

## 0. Why the shift

| Book | Idle USDC | Can fund ops? |
|------|-----------|----------------|
| Kingdom RSS/USDC `0x40ac09f3…` | ~$1 | No |
| cbBTC/USDC (curator-fed) | **~$146M** | Yes |
| USDe/USDC | **~$26M** | Yes (riskier coll) |
| WETH/USDC | **~$8M** | Yes |

Idle = `supply − borrow` (Morpho API `liquidityAssetsUsd`). That is cash available to borrow **now**.

---

## 1. Primary target market (whale #1)

| Field | Value |
|-------|--------|
| Market ID | `0x9103c3b4e834476c9a62ea009ba2c884ee42e94e6e314a26f04d312434191836` |
| Collateral | **cbBTC** `0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf` |
| Loan | USDC |
| LLTV | **86%** |
| IRM | Adaptive Curve `0x46415998764C29aB2a25CbeA6254146D50D22687` |
| Oracle | `0x663BECd10daE6C4A3Dcd89F1d76c1174199639B9` |
| Live idle (snapshot) | **~$146M USDC** |
| Util | ~90% |
| Fed by vaults | Gauntlet USDC Prime `0xeE8F…b61`, Steakhouse USDC `0xbeeF01…183`, Steakhouse Prime `0xBEEFE9…3b2`, Gauntlet Core `0xc0c568…b12`, Spark, Moonwell, Yearn OG, etc. |

**Secondary:** WETH/USDC `0x8793cf30…1bda` (~$8M idle, LLTV 86%) if ETH collateral is easier to source.

---

## 2. Collateral gate (blocker today)

Hot `0x6708…a7d1` holds:
- RSS ~18.5M (sovereign — **not** collateral on whale markets)
- cbBTC ≈ **dust** (~0.000018 BTC)
- WETH / wstETH / cbETH = **0**
- USDC ≈ **$0.10**

**Eng requirement before any borrow:** acquire **accepted collateral** for the chosen market (cbBTC or WETH), sized for LTV.

Example for **$500k USDC** borrow on cbBTC/86% LLTV (stay ≤ ~70–80% soft for safety):
- Need collateral value ≈ `$500k / 0.80` ≈ **$625k** cbBTC (mark-to-oracle).
- Exact sat sizing = `cast` against oracle `price()` at execution time.

RSS does **not** unlock this market. Track A = buy/bridge cbBTC (or WETH). Track B = keep RSS market for sovereign rails only.

---

## 3. Execution architecture (scripts)

**Do not** reuse `FireWarElephant` / RSS market ID for this path.

New module (suggested):
- `script/FireWhaleBorrow.s.sol`
- `script/PreflightWhaleMarket.s.sol`

### Preflight (must print READY=1/0)
1. `market(marketId)` → `liquidityAssets >= BORROW_USDC`
2. Hot holds collateral ≥ required
3. Oracle price sane; soft LTV ≤ 80% of LLTV
4. Hot ETH gas ≥ **0.02** (top up from ~0.005 today)
5. Landing address = `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357`
6. No flash self-seed required — **direct** `supplyCollateral` + `borrow` to Landing

### Phase 1 — Borrow (one tx path)
```
HOT: Morpho.supplyCollateral(cbBTC market, amount, HOT)
HOT: Morpho.borrow(USDC, 500_000e6, HOT, LANDING)  // receiver = cold
```
Gates: `KING_GO=1 FIRE_WHALE=1 BORROW_USDC=500000000000`

### Phase 2 — Verify
- Basescan: Landing USDC **+$500k**
- Morpho position: collateral + borrowShares on HOT
- Market idle still healthy post-borrow

### Every live test size
**$500k USDC** until King raises the ladder.

---

## 4. Ops checklist (eng)

| Step | Owner | Output |
|------|--------|--------|
| Refresh idle via Morpho API / app | Eng | Snapshot CSV + marketId |
| Source cbBTC (or WETH) to HOT | King/Treasury | Balance ≥ sizing sheet |
| Top up HOT ETH to ≥ 0.02 | King | Gas ready |
| Ship `PreflightWhaleMarket` | Eng | READY=1 |
| Ship `FireWhaleBorrow` | Eng | Broadcast on King go |
| Document tx hashes | Eng | `deployments/WHALE-BORROW-LIVE.md` |
| Repay/unwind runbook | Eng | `repay` + `withdrawCollateral` script |

---

## 5. Risk notes (eng)

- Borrow APY on deep markets is live — accrue debt in USDC.
- Liquidation if cbBTC/WETH drops through LLTV — keep soft LTV buffer.
- Public Allocator may refill idle; still size borrow **<<** displayed idle.
- Sovereign RSS/V2 path stays separate; do not merge scripts.

---

## 6. Definition of done

1. Preflight READY on cbBTC/USDC (or WETH/USDC).  
2. Live **$500k** USDC on Landing in one borrow tx.  
3. Position + repay path documented.  
4. Next size only after King go.

**API refresh:** `https://blue-api.morpho.org/graphql` — markets where `chainId=8453`, `loanAsset=USDC`, order by `liquidityAssetsUsd`.
