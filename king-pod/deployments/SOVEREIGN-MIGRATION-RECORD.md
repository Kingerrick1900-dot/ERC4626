# Sovereign migration — fork PASS · treasury bridge

**Status:** Fork proofs green · awaiting live `FIRE_SOVEREIGN_MIGRATE=1`  
**Chain:** Base · legacy `0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88`

---

## Walls

| Wall | Status |
|--|--|
| 1 Allowance | **DOWN** — `rss.approve(MORPHO, type(uint256).max)` from migrator holding RSS |
| 2 Flash shortfall | **BRIDGED** — Morpho flash + King treasury delta; yRSS unlocks after repay for flash repay |
| 3 Git | Commit this record + code |

---

## Sequence (implemented)

1. Accrue + measure debt / Morpho USDC cash  
2. **Path A** (treasury full): King (+ yRSS) USDC ≥ debt → repay → withdraw RSS to migrator  
3. **Path B** (flash + bridge): `flashAmt = min(debt, morphoCash)` · `delta = debt - flashAmt` from HOT  
4. Repay legacy in full  
5. Pull yRSS USDC (idle opens after repay) → fund flash repay  
6. `withdrawCollateral(legacy, coll, king, address(this))`  
7. `rss.approve(MORPHO, type(uint256).max)`  
8. `supplyCollateral(sovereign, bal, king, "")`  

**Note:** New sovereign market has **no lenders** at create — cannot re-borrow USDC there in the same tx to refill treasury. Position lands **debt-free** under King’s oracle (LTV 0). Paper LTV if same debt re-opened at $50k ≈ **2.04%**.

---

## Fork tests

```bash
cd king-pod
BASE_RPC_URL=https://mainnet.base.org \
  forge test --match-test test_sovereign_migration -vv
```

| Test | Path | Result |
|--|--|--|
| `test_sovereign_migration` | Full treasury USDC | **PASS** |
| `test_sovereign_migration_flash_treasury_bridge` | Flash + delta only | **PASS** (when yRSS unlocks) |

---

## Live fire

```bash
FIRE_SOVEREIGN_MIGRATE=1 HOT_KEY=$HOT_KEY \
  forge script script/FireSovereignMigrate.s.sol:FireSovereignMigrate \
  --rpc-url "$BASE_RPC_URL" --broadcast --slow --with-gas-price 6000000
```

**Pre-approvals (HOT):** `USDC` + `yRSS` → migrator · `Morpho.setAuthorization(migrator, true)`  
**Capital:** Path A needs ~debt USDC on HOT; Path B needs ~delta (~$30M if Morpho cash ~$234M / debt ~$263M).

---

```
SOVEREIGN_MIGRATION=FORK_PASS
RSS_APPROVE=TYPE_MAX_UINT
TREASURY_BRIDGE=1
LEGACY_ORACLE=IMMUTABLE
NEXT=FIRE_SOVEREIGN_MIGRATE=1
```
