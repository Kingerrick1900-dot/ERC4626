# Loop to mark

## Command
Stop waiting. Loop the proven $2 flash-elite pattern until Cake hits `$700k` or rails are dry.

```bash
PRIVATE_KEY=… ./script/loop-to-mark.sh
# or
forge script script/LoopEliteToMark.s.sol:LoopEliteToMark --rpc-url $BASE_RPC --broadcast
```

## Each loop
1. Harvest leftover Morpho supply → King
2. Seed **all** King USDC into desk
3. `eliteFlashClose` (desk-only, Morpho rail flashed) → Cake vault `+$B`
4. Repeat until vault ≥ `$700k` **or** desk/King < `$0.10`

## Live closer
`0x2192251a8FD4a31843fDE1222C43Ac0ad64ccD25` → treasury Cake `0xA1aF…832a`

## How the stack grows
Every round parks rail USDC into Cake. Re-run the moment new USDC hits King — the loop eats it into the vault. Rails dry right now because prior shots already moved available USDC into Cake (`~$4.87`). Next fuel on King → fire again → vault climbs.
