# Path B — Self-fund migration (Path A struck)

**Law:** The King does not inject external USDC. Path A (treasury bridge) is **REMOVED**.

---

## How is there debt if the King never had real USDC?

On-chain fact (not a metaphor):

| Item | Live |
|--|--|
| Market | `0x41c08085…7d88` (RSS/$1200) |
| Collateral | **252,000 RSS** posted by HOT |
| Borrow | **~$257M USDC** owed by HOT to Morpho |
| Who funded the USDC | **Suppliers** — chiefly **yRSS** (`0xF80C…`) which supplied the book |

The King did not need USDC in his wallet to open this. Morpho lends **suppliers’ USDC** against collateral. HOT borrowed it. The debt is real. Repayment returns USDC to those suppliers (yRSS equity), not to a fiat bill from outside.

Scoreboard HOT USDC (~$0.33) is unrelated to how the borrow was created.

---

## Why “borrow on the new market first” does not work

Scribe sketch: borrow $22.8M on `0x1293…` → repay legacy → move RSS.

**Blocked twice:**

1. **RSS is locked** on the legacy market until debt is cleared — cannot post it on `0x1293…` first.  
2. **Sovereign market has no lenders** — `createMarket` only; zero USDC supply → `borrow` cannot draw $22.8M.

So Path B is **not** “borrow on 0x1293 first.” Path B is **flash + yRSS** (Kingdom rails already in the book).

---

## Real Path B (architecture)

```
Morpho flash (singleton USDC)
  → repay legacy (opens idle in 0x41c0)
  → withdraw King yRSS (vault equity — system capital)
  → finish debt + repay flash
  → withdraw 252k RSS to migrator
  → approve(MORPHO, max) + supplyCollateral(sovereign)
```

No King wallet USDC. Capital path = temporary Morpho flash + King’s **yRSS shares**.

---

## Hard constraint (live)

| Meter | Approx |
|--|--:|
| HOT debt (pre-accrue) | ~$257.3M |
| HOT yRSS assets (~98.53% of vault) | ~$258.4M |
| Other yRSS holders | ~**1.47%** |
| Morpho flash cash | ~$234.7M |

After `accrueInterest`, debt can **exceed** HOT’s yRSS claim for a moment → `SystemShort`.  
Minority vault shareholders also trap ~1.5% of unlocked idle so HOT cannot withdraw 100% of market liquidity.

**Fork must prove** `test_path_b_self_fund_no_treasury` with **no `deal(USDC, HOT)`**.

---

## Commands

```bash
# Fork proof (no treasury inject)
BASE_RPC_URL=https://mainnet.base.org \
  forge test --match-test test_path_b_self_fund_no_treasury -vv

# Live (when proof green)
FIRE_SOVEREIGN_MIGRATE=1 HOT_KEY=$HOT_KEY \
  SOVEREIGN_ORACLE=0x22E2F66a26eA8d01E0Bb4154ef4DfB0304a34f2d \
  SKIP_CREATE_MARKET=1 \
  forge script script/FireSovereignMigrate.s.sol:FireSovereignMigrate \
  --rpc-url $BASE_RPC_URL --broadcast --slow --with-gas-price 6000000
```

---

```
PATH_A=REMOVED
PATH_B=FLASH_PLUS_YRSS
BORROW_ON_1293_FIRST=IMPOSSIBLE
DEBT_ORIGIN=MORPHO_BORROW_VS_RSS_FUNDED_BY_YRSS
```
