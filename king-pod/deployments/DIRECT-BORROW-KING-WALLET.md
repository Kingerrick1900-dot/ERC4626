# Direct borrow — King wallet (no circle)

**Correct shape (King ordered):**  
`supplyCollateral(RSS)` → `borrow(USDC, receiver = King wallet)` → **keep it**.  
No vault re-deposit. No flash loop. No yRSS park.

**Script:** `king-pod/script/FireDirectBorrow.s.sol`

```bash
KING_GO=1 FIRE_DIRECT=1 BORROW_USDC=9000000000000 KING_WALLET=0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357 \
  PRIVATE_KEY=<hot> forge script script/FireDirectBorrow.s.sol:FireDirectBorrow \
  --rpc-url $RPC --broadcast -vvvv
```

| Param | Default | Meaning |
|-------|---------|---------|
| `KING_WALLET` | Landing cold | Where USDC lands and stays |
| `BORROW_USDC` | $9M | Capped by soft LTV 70% **and** market idle |
| `RSS_COLL` | full hot RSS | Collateral posted |

## Gate now (live)

RSS/USDC Morpho idle ≈ **$1**. Soft LTV on 18.5M RSS @ $1 allows ~**$12.9M**, but Morpho will only lend what suppliers deposited.

**Cannot restore a $9M wallet draw until USDC supply sits in this market.**  
Script is armed and will refuse thin idle (`IDLE TOO THIN`) so we don’t post RSS into a failed borrow.

## When idle ≥ draw

One tx → USDC on King wallet → Morpho debt + RSS coll on hot → spendable capital. Position back the **right** way.
