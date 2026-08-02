# Flash + balanceOf-bound reserves → Landing

**Status: LIVE ON BASE.** Flash-bound attest fired.  
**Branch:** `cursor/flash-bound-reserves-landing-4f7f` · **PR:** #88

## Live addresses (Base)

| Contract | Address |
|----------|---------|
| Groth16Verifier (reused) | `0xCC1223C0fCA9efe6c4ea4b35A8b9F08b3f8aF681` |
| **CrownBoundReservesGate** | `0xab2856626BBd8E6fba9dB93783029eB973E8427F` |
| **CrownZkCredit** | `0x20B1513a137b9CB166E2cC15c405e842278E7D1A` |
| **CrownFlashBoundAttest** | `0x22C07d684ca8D5963A94e17C8e78B9e6105f34F4` |
| **CrownBoundLandingCompleter** | `0x3827dA0c33891ee058847BB896D6287C5814F7C6` |
| **CrownZkAutoDraw** | `0x364bEF6c5A3DC2c02D7ECf1e12a2d1F08B0513ba` |
| Landing | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| Subject (hot) | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |

## Live state (post-fire)

| Check | Value |
|-------|-------|
| `gate.isProven(hot)` | **true** |
| Attested threshold | **700_000e6** ($700,000) |
| Hot USDC | **0** (flash repaid — net zero) |
| Credit USDC / `maxBorrow` | **0** / **0** |
| Landing USDC | dust (~945003 raw) — **unchanged by flash** |
| Wiring | attestor(flash)=true · operators flash/completer/autodraw=true · flash.credit set |

### Key txs
- Deploy (partial first wave): gate/credit/flash/completer — see `broadcast/FireBoundReservesDeploy.s.sol/8453/`
- Wire + AutoDraw + **`fireLive(700_000e6)`**: `0x8bc315eedbff9c4ce6bf2cf783e7c2cdbe092ded4dcc67964f492f68a63d1b5d`
- Full wire/fire broadcast: `broadcast/FireBoundWireAndFlash.s.sol/8453/run-latest.json`

## What this is

Closes the free-witness hole in the Circom reserves stack:

| Old path | New path |
|----------|----------|
| Off-chain prove with private `usdcBalance` (any number) → `submitProof` | Live `IERC20(USDC).balanceOf(subject) >= threshold` **required** |
| Flash “prove $700k” without holdings | Morpho flash parks USDC on hot → attest → repay **same tx** |

## Physics (no hope)

1. **Flash unlock** sets `isProven(hot)=true` without pocket USDC. Repay consumes the flash → hot net-zero. **PROVEN LIVE.**
2. **Landing lasting ≥ $500k** still needs a **named USDC source after unlock**:
   - matcher / LP `credit.supply` then completer/autodraw, or
   - credit already funded before `fireLive` (same-tx poke to Landing), or
   - wet-market borrow / vault idle (separate rails).
3. Caps ≠ cash. `isProven` ≠ Landing seed.

## Re-fire / matcher

```bash
# Re-attest (TTL refresh) — King GO
KING_OK=1 FIRE_BOUND_WIRE=1 PRIVATE_KEY=0x… \
  GATE=0xab2856626BBd8E6fba9dB93783029eB973E8427F \
  CREDIT=0x20B1513a137b9CB166E2cC15c405e842278E7D1A \
  FLASH=0x22C07d684ca8D5963A94e17C8e78B9e6105f34F4 \
  COMPLETER=0x3827dA0c33891ee058847BB896D6287C5814F7C6 \
  forge script script/FireBoundWireAndFlash.s.sol:FireBoundWireAndFlash \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

Matcher: approve Completer, then `complete(amount)` with `amount ≤ 70% · 700k = 490k` once credit has USDC.

## Tests

```bash
forge test --match-contract FlashBoundReservesTest -vv
forge test --match-contract FlashBoundReservesForkTest -vv
```

## Security

- Hot key was exposed in chat — **rotate**.
- Do not commit keys. Env only: `PRIVATE_KEY` / `SCROLL_PRIVATE_KEY`.
- Hot is EIP-7702 delegated; forge broadcasts need `--slow` (in-flight limit).
- Storage-proof (Noir / `eth_getProof`) binding is Phase B.
