# Scroll eUSD rail — convert 100k / keep 545k

**Doctrine:** Landing holds ~**645,167 eUSD**. Rail converts **100,000 eUSD → USDC** only. **≥545,000 eUSD stays on Landing.** Gold CDP treasure (100,001 kXAU) untouched.

## Caps

| Cap | Amount |
|--|--|
| **CONVERT** | `100_000e18` eUSD |
| **KEEP on Landing** | `545_000e18` eUSD (floor) |
| Live Landing | ~`645_167e18` eUSD |

`645,167 − 100,000 ≈ 545,167` → floor holds.

## Sequence

1. **Landing → Scroll hot:** transfer exactly `100_000e18` eUSD  
2. **Hot:** `FireScrollEusdRail` swaps eUSD→USDC (Uni V3 0.3% `0x5f3f2234…` when depth exists, or PSM when reserved)  
3. USDC lands on Scroll hot (or Landing if `TO_LANDING=1`)  
4. Script reverts if Landing eUSD would fall below `545_000e18`

## Blockers (live)

| Need | Status |
|--|--|
| Landing → hot `100k` eUSD | Need Landing signer (hot key cannot move Landing EOA) |
| ~`100k` USDC depth (pool or PSM) | Scroll hot USDC dust only (~$0.07); pool ~$0.20 |

Gold CDP / 100,001 kXAU: **do not touch**.

## Fire

```bash
# After Landing wires 100k eUSD to hot AND USDC depth exists:
KING_GO=1 FIRE_EUSD_RAIL=1 \
forge script script/FireScrollEusdRail.s.sol:FireScrollEusdRail \
  --rpc-url "$SCROLL_RPC" --broadcast --slow --private-key "$SCROLL_PRIVATE_KEY"
```
