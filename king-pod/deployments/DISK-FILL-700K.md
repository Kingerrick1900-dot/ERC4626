# Disk fill $700k — working path (fork-proven)

## Hard correction

**yELE asset = USDC.** You cannot deposit ELE into yELE.  
King-as-source = deposit **USDC** into yELE (WETH market) after `acceptCap`.

Fork proof: `DiskFillWarped` → Landing **+$699,999.999998**.

## Sequence

### Now (optional): surface ELE from Morpho

```bash
KING_GO=1 FIRE_SURFACE_ELE=1 forge script script/SupplyEleToVault.s.sol:SupplyEleToVault \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
```

Withdraws 14M ELE coll → hot (keeps HF ≥ 1.55). Does **not** fund the vault.

### After `validAt` 1785092927 + USDC on hot

```bash
# One-shot: acceptCap → queue WETH→ELE → deposit ASK → curatorDiskFill → Landing
KING_GO=1 FIRE_DISK_FILL=1 ASK_USDC=700000000000 \
forge script script/FireDiskFill700k.s.sol:FireDiskFill700k \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
```

Or split:

```bash
KING_GO=1 FIRE_ACCEPT_CAP=1 forge script script/FireAcceptCap.s.sol:FireAcceptCap \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
# then FIRE_DISK_FILL with USDC already on hot
```

## Machine

`CrownLeverageExtractor.curatorDiskFill`:
1. `yELE.reallocate` WETH→ELE (allocator — no PA maxOut trap)
2. `borrow` → Landing

Requires: WETH market enabled, yELE holding USDC on WETH, extractor set as allocator + Morpho auth.
