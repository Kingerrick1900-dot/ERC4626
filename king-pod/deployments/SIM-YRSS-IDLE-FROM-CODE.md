# SIM — yRSS idle engineered from code alone (never done)

**Mode:** FORK SIM · Base  
**Rule:** no `deal(USDC)` · no repeating elite-$5M-PA or BRETT-seed unlock  
**Status:** **PASS** · `test/SimYrssIdleFromCode.t.sol`

---

## Grand fine print (King ultimate favor)

| # | Fine print | Why it favors the King |
|--|--|--|
| 1 | **Morpho `flashLoan`** | Temporarily spends **foreign books' USDC** already sitting on Morpho (cbBTC idle etc.). No King prefund. |
| 2 | **`supply(onBehalf: yRSS)`** | Anyone can credit Morpho inventory to yRSS **without minting vault shares** → share price rises for the 99.95% King LP. |
| 3 | **withdrawQueue vs IDLE** | Idle-market `0x38c8…` can hold true unmatched USDC. If omitted from `withdrawQueue`, donations strand. King `timelock=0` can add it and make engineered idle **exitable**. |
| 4 | **King = eUSD owner + minter** | Mint eUSD collateral from code, borrow the parked USDC, repay flash → **permanent yRSS Morpho inventory** with no external USDC deposit. |

These are not the elite PA $5M door and not the BRETT→supply→withdraw unlock. New machine.

---

## Sims that passed

### A — Flash + onBehalf → yRSS IDLE (mid-flight proof)

```
Morpho.flashLoan($5M USDC)          // foreign cash
  → supply(IDLE, onBehalf: yRSS)    // engineer idle inside yRSS
  → maxWithdraw(HOT) ≥ $5M          // exit open
  → withdraw $5M → repay flash      // unwind proof
```

| Meter | Value |
|--|--:|
| totalAssets before | 259,252,135,555,086 |
| mid maxWithdraw | **5,000,000e6** |
| mid idle shares | **5e18** |
| mid totalAssets | **264,252,135,555,086** (+$5M) |

### B — Permanent inventory via eUSD mint + flash

```
Morpho.flashLoan($5M)
  → supply(eUSD/USDC market, onBehalf: yRSS)
  → eUSD.mint(HOT, collateral)          // King minter
  → supplyCollateral + borrow $5M → repay flash
```

| Meter | Value |
|--|--:|
| yRSS eUSD-market shares before | 0 |
| yRSS eUSD-market shares after | **>0** |
| totalAssets | **+$5,000,000e6** |

No `deal(USDC)`. Bootstrap is mint rights + Morpho flash fine print.

---

## Run

```bash
forge test --match-contract SimYrssIdleFromCodeTest -vv --fork-url $BASE_RPC_URL
```

```
YRSS_IDLE_FROM_CODE=PASS
NO_DEAL_USDC=1
PATH_A=flash→onBehalf IDLE→maxWithdraw
PATH_B=flash→onBehalf eUSD-mkt→mint eUSD→borrow→repay
NEXT=live_arm_only_on_King_order
```
