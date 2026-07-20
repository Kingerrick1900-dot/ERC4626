# Fix: "still needs USDC in the market"

**Problem:** Direct borrow to King wallet fails when RSS/USDC idle ≈ $0.  
**Wrong answer:** "King must deposit USDC."  
**Right answer:** **Morpho Public Allocator** — just-in-time liquidity. Already in the Kingdom stack.

---

## Morpho mechanism (docs)

> *The Public Allocator moves a vault's idle or under-utilized assets into a market where a borrower needs them, right at the moment they need them.*

No King cash. USDC is **reallocated from deep curator markets** into RSS/USDC, then borrowed to wallet.

---

## Already armed on-chain

| Item | Status |
|------|--------|
| Public Allocator (Base) | `0xA090dD1a701408Df1d4d0B85b716c87565f90467` |
| yRSS vault | `0xF80C0529bD94C773844E459853CD91B9263dD525` |
| PA admin | Hot (King) |
| PA fee on yRSS | **0** |
| Flow caps RSS market | **maxIn ~$699k / maxOut ~$700k** |
| RSS/USDC market | `0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794` |

Scripts already in repo: `ArmYrssPipe.s.sol`, `ArmYrssMultiMarket.s.sol`, `FirePositionSeed700k.s.sol` (PA pull pattern).

---

## Restore sequence (3 steps, no King USDC)

### Step A — Prime pull source (if yRSS has no USDC in cbBTC/WETH book)
Curator runs `ArmYrssMultiMarket` + **reallocate / deposit** so yRSS holds USDC in a **source market** with `maxOut` (e.g. cbBTC/USDC `0x9103…1836`).

### Step B — JIT liquidity into RSS market
`FireKingLoanRestore.s.sol`:
```
PA.reallocateTo(yRSS, withdraw cbBTC/USDC, supply RSS/USDC)  // up to $500k–$700k
```
Fills RSS market idle **without King wallet USDC**.

### Step C — Real loan to wallet
Same tx (or `FireDirectBorrow` after B):
```
supplyCollateral(RSS) → borrow(USDC → King wallet) → keep it
```
No yRSS park. No circle.

---

## Script (new)

```bash
# Step B+C combined (King go)
KING_GO=1 FIRE_RESTORE=1 BORROW_USDC=500000000000 \
SRC_COLLATERAL=0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf \
SRC_ORACLE=0x663BECd10daE6C4A3Dcd89F1d76c1174199639B9 \
SRC_LLTV=860000000000000000 \
PULL_USDC=500000000000 \
PRIVATE_KEY=<hot> forge script script/FireKingLoanRestore.s.sol --rpc-url $RPC --broadcast -vvvv
```

| Env | Default | Role |
|-----|---------|------|
| `KING_WALLET` | Landing cold | USDC lands here |
| `PULL_USDC` | $500k | PA pull size |
| `BORROW_USDC` | $9M cap | Capped by idle + 70% LTV |
| `SRC_*` | cbBTC/USDC book | PA withdraw source |

---

## Access after loan (V2, separate tx)

Morpho `forceDeallocate` on Vault V2 — Phase 2 when King wants vault slice out. Not mixed into loan tx.

---

## Done when

1. PA pull fills RSS idle (visible on Morpho app: Supply − Borrow ≥ draw).  
2. Borrow tx: USDC on King wallet, debt + RSS on hot.  
3. No "still needs" — liquidity program **is** PA + yRSS rails King already owns.
