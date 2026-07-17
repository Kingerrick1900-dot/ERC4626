# ENGINEERING PLAN — Position is the seed

## Law
Oracle + PoD book engineer the Morpho position. Liquidity follows the position. Seed is **output**, not input. No wait chairs. No relocate dust loops.

## Live machine (Base)
1. **Oracle** — RSS @ **$1** (King-owned)
2. **PoD** — **~$9.25M** supply/borrow, **100% util**, HF~1.54, borrow headroom **~$5M**
3. **PA** — yRSS maxIn **$700k** formalized; packet broadcasts position to Gauntlet/Steakhouse
4. **Borrow rail** — SpoilFire + `FirePositionSeed700k` → KingVault `0xA1aF…`

## Fire command
When reallocatable USDC exists on a vault with RSS maxIn:
```bash
PULL_USDC=700000000000 \
PA_VAULT=0x… \
WITHDRAW_LOAN=0x8335… \
WITHDRAW_COLLATERAL=… \
WITHDRAW_ORACLE=… \
WITHDRAW_IRM=0x4641… \
WITHDRAW_LLTV=… \
forge script script/FirePositionSeed700k.s.sol:FirePositionSeed700k --broadcast
```

## Kill list
- “When money arrives” as step 0
- Play 5→3 dust relocate called profit
- Sending ops USDC into Cake (receive-only)
- Spinning curator politics as the engine (packet is broadcast of position, not the engine)
