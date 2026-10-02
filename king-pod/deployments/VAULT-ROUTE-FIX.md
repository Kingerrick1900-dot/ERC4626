# Vault-route fix — King's gold is not a debug budget

**Doctrine:** Fix the code. Verify the vault holds the shares. Then fire small. Then scale.  
**Forbidden:** Firing $50M/$107M/$200M through `CrownLoopNative` (ghost path). No loop. No exit. Until verified.

---

## The failure (honest)

| Claim | Fact |
|--|--|
| “Loop proven” | **False.** `CrownLoopNative` did `morpho.supply(onBehalf=king)`. Vault never received the USDC. |
| Morpho market depth | ~$200M supply/borrow on eUSD/USDC — **king positions**, not vault |
| ySYNTH `totalAssets` | **~$1.33** — the real vault balance |
| Exit | Cannot draw what the vault does not hold |
| Deposit panic | Supply queue included Morpho IDLE (zero-IRM) → deposit underflow. **IDLE purged** (Step 1). |

---

## The fix (code)

| Old | New |
|--|--|
| `CrownLoopNative` — flash → `morpho.supply(king)` | **Frozen — do not fire** |
| — | `CrownLoopViaVault` — flash → **`ySYNTH.deposit(king)`** → borrow idle → repay |

Contract: `src/CrownLoopViaVault.sol`  
Defaults: `maxFlash = $1`, `armed = false`. Cap must be raised explicitly. No silent scale.

---

## Verification order (King-approved)

1. **IDLE purged from supplyQueue** — done (`0x062e13c6…18c9`)
2. **Vault math reconciled** — `totalAssets≈1330905`, USDC bal 0 (assets in Morpho), `lastTotalAssets` lag noted
3. **Controlled $1 deposit through vault** — prove `balanceOf` / `totalAssets` move
4. Deploy `CrownLoopViaVault`, arm at `$1` max, one fire — prove vault shares increase
5. Only then raise `maxFlash` under King order

---

## Scoreboard

```
GHOST_LOOP=CrownLoopNative FROZEN
FIX=CrownLoopViaVault (deposit through ySYNTH)
MAX_FLASH_DEFAULT=$1
SCALE=forbidden until vault share ownership verified
```
