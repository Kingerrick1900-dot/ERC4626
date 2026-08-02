# Flash + balanceOf-bound reserves → Landing

**Status:** Engineered complete (deploy + fire gated on King `KING_OK`).  
**Branch:** `cursor/flash-bound-reserves-landing-4f7f`

## What this is

Closes the free-witness hole in the Circom reserves stack:

| Old path | New path |
|----------|----------|
| Off-chain prove with private `usdcBalance` (any number) → `submitProof` | Live `IERC20(USDC).balanceOf(subject) >= threshold` **required** |
| Flash “prove $700k” without holdings | Morpho flash parks USDC on hot → attest → repay **same tx** |

## Contracts

| Piece | Role |
|-------|------|
| `CrownBoundReservesGate` | ZK+`balanceOf` (`submitBoundProof`) or attestor `attestLive` |
| `CrownFlashBoundAttest` | Morpho `flashLoan` → park on hot → attest → pullback → repay; optional credit poke |
| `CrownZkCredit` | Proven king draws ≤ LLTV·threshold to Landing |
| `CrownBoundLandingCompleter` | Matcher `complete`: supply → `operatorBorrowTo(Landing)` |
| `CrownZkAutoDraw` | Permissionless poke via `operatorBorrowTo` (fixed) |

## Physics (no hope)

1. **Flash unlock** sets `isProven(hot)=true` without pocket USDC. Repay consumes the flash → hot net-zero.
2. **Landing lasting ≥ $500k** still needs a **named USDC source after unlock**:
   - matcher / LP `credit.supply` then completer/autodraw, or
   - credit already funded before `fireLive` (same-tx poke to Landing), or
   - wet-market borrow / vault idle (separate rails).
3. Caps ≠ cash. `isProven` ≠ Landing seed.

## Deploy (King GO)

```bash
cd king-pod
KING_OK=1 FIRE_BOUND_DEPLOY=1 PRIVATE_KEY=0x… \
  forge script script/FireBoundReservesDeploy.s.sol:FireBoundReservesDeploy \
  --rpc-url $BASE_RPC_URL --broadcast
```

Writes: BoundGate, Credit(landing), FlashBoundAttest, Completer, AutoDraw.  
Sets attestor + operators. Reuses live verifier `0xCC1223C0…F681` unless `REUSE_VERIFIER=0x0` (deploy fresh).

## Fire flash attest (King GO)

```bash
# hot must be subject; approve is inside the script
KING_OK=1 FIRE_BOUND_FLASH=1 PRIVATE_KEY=0x… \
  FLASH=0x… GATE=0x… AMOUNT=700000000000 \
  forge script script/FireBoundFlashLive.s.sol:FireBoundFlashLive \
  --rpc-url $BASE_RPC_URL --broadcast
```

## Matcher Landing fill (after proven)

Matcher approves Completer, then `complete(amount)` with `amount ≤ 70% · attested`.

## Tests

```bash
forge test --match-contract FlashBoundReservesTest -vv
BASE_RPC_URL=… forge test --match-contract FlashBoundReservesForkTest -vv
```

## Security

- Hot key was exposed in chat historically — **rotate** after any live fire.
- Do not commit keys. Env only: `PRIVATE_KEY` / `SCROLL_PRIVATE_KEY`.
- Storage-proof (Noir / `eth_getProof`) binding is Phase B — see section below. Phase A `balanceOf` is the live binding.

## Phase B — storage proofs (not shipped)

Bind attestation to a Base block’s USDC `balanceOf` storage slot via EIP-1186 account/storage proofs verified on-chain (or Noir). That proves historical holdings without a same-block flash. Harder stack; does not replace flash for atomic unlock. Track separately if King orders it.
