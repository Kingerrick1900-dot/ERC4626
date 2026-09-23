# CROWN UNLATCH IDLE — lasting unmatched Morpho USDC

**Status:** LIVE  
**Branch:** `cursor/morpho-create-idle-2m-4f7f`  
**Law:** Idle = supply − borrow. Never borrow. Never gasPark. Buffer protects engineered idle from peel.

---

## Live

| | |
|--|--|
| **CrownUnlatchIdle** | `0xEC847430Ac0667B75A0a0647a269ee286587FFC4` |
| Market | `0x41c08085…` (yRSS park) |
| First engineer | swept PSM **1.514570 USDC** → `engineerIdle` |
| Idle after | **1.514572 USDC** (was 2 wei) |
| utilBps | **9999** (was 10000) |
| minIdleBuffer | locks that idle so peel cannot re-latch by draining it |

---

## What “unlatched idle we don’t have” means

Park book was **100% util** because gasPark matched vault supply with king borrow (~$1M excess borrow vs HOT supply). Unmatched idle did not exist.

`engineerIdle(amt)` supplies USDC **direct** to Morpho on this contract. Borrow shares of king do not rise. Idle appears and `minIdleBuffer` auto-raises so `peelSurplus` / `pokePeel` can only take **surplus above the buffer**.

Scale path (honest): rail real USDC to HOT → `FireUnlatchEngineer` with `AMT`. $1M lasting idle needs ~$1M USDC (or `unlatchRepay` of the same size). Flash+re-borrow is refused (`NoBorrow`).

---

## Ops

```bash
# Deploy + sweep PSM + engineer whatever USDC HOT holds
KING_GO=1 SWEEP_PSM=1 ENGINEER=1 forge script script/FireUnlatchIdle.s.sol:FireUnlatchDeploy \
  --rpc-url $BASE_RPC_URL --broadcast --slow

# Later, after USDC rail lands on HOT
KING_GO=1 FIRE=1 UNLATCH=0xEC847430Ac0667B75A0a0647a269ee286587FFC4 AMT=1000000000000 \
  forge script script/FireUnlatchIdle.s.sol:FireUnlatchEngineer \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

King must `yRSS.approve(0xEC84…FFC4, max)` before any peel.

## Tests

```bash
forge test --match-contract CrownUnlatchIdleTest -vv
```

## Security

HOT key was pasted in chat for this fire — **rotate after ops**.
