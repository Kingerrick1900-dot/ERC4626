# ZK Circuit Constraint Audit + Hardening

**Status:** Circuit + gate hardened in-repo. **Certora Prover not available in this environment** (blocker for full formal verification run). Specs live under `certora/`. Redeploy of a new Groth16 VK requires `KING_GO` + trusted setup rebuild — not broadcast here.

## Live surface (reference)

| Piece | Address |
|-------|---------|
| eUSD (multi-minter) | `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a` |
| Elepan CDP | `0xD0108e7570dB003D8140949d2b68Dd3e3F81ED14` |
| WETH CDP | `0x60033c198bb686cEA1BAAF5a5CDc7b6e3Ddc9BCF` |
| cbBTC CDP | `0xb7Be10165c7A3296Cb621478B3dD497c65Da28d5` |
| ZK Gate | `0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30` (`isProven(hot)=true`) |
| ZK Credit Rail | `0xc4152c73824d85146B0f85a0b77E911D4769d936` (pool USDC=0) |

## Attack class (Aztec Connect / under-constraint)

If a witness is not `assert_equal`-bound to the public statement, a prover can satisfy the circuit while minting attestation against nonexistent reserves. On-chain, that becomes `isProven(attacker)=true`. CDP mint remains `onlyOwner`, but credit-rail / operator paths that key off the gate alone are exposed; King wallet-bind also becomes forgeable if the circuit is broken.

## Constraint audit (`wallet_reserves.circom`)

| Witness / signal | Constraint | Status |
|------------------|------------|--------|
| `kusd` | `Num2Bits(n)` range + Poseidon in[0] | Bound |
| `rss` | Exact div identity `rss === rssValue*1e12 + rem` | Bound |
| `rssValue` | `Num2Bits(n)` + used in `total` | Bound |
| `rem` | `Num2Bits(40)` + `LessThan(1e12)` | Bound |
| `salt` | Poseidon in[2] | Bound into commitment |
| `threshold` (public) | `Num2Bits(n)` + `GreaterEqThan` | Bound (not free) |
| `subject` (public) | `Num2Bits(160)` + identity rebind | Bound to address width |
| `ok` (output) | `GreaterEqThan` + `ok*(ok-1)===0` | Boolean |
| `commitment` | Poseidon out | Bound |
| `numTxs` | N/A — single-shot circuit | Documented; multi-tx circuits MUST bind `numTxs` to full proven set |

### On-chain public-input policy (`CrownZkWalletGate` + `ProofVecGuard`)

- `ok == 1`
- `minThreshold ≤ threshold ≤ MAX_THRESHOLD`
- `subject ≤ uint160.max` and nonzero
- every public limb `< SNARK_SCALAR_FIELD`
- dynamic `submitProofVec`: length must equal 4 and `≤ MAX_PUBLIC_SIGNALS` (never allocate from raw attacker length)

## Fallback mechanism (CDP)

`zkFallbackEnabled` (King-only toggle):

- When ZK attestation fails/expires and fallback is **armed**, King can still `deposit` / `mint` / … via **direct on-chain collateral lock**.
- HF + real ERC20 transfer checks are unchanged — no mint against nonexistent coll.
- Non-owner cannot use fallback.
- Events: `ZkFallbackSet`, `ZkFallbackUsed` for monitors.

## Silent-failure monitoring

ZK bugs often **succeed** as transactions. Gate emits `SilentFailureFlag` and exposes `checkSilentFailure(subject)`:

| Code | Meaning |
|------|---------|
| `ZERO_COMMIT` | Proof accepted with commitment 0 |
| `THRESH_LOW` / `THRESH_HIGH` | Stored threshold vs policy |
| `FUTURE_TS` | `provenAt` in the future |
| `STALE_VALID` | TTL expired but storage still `valid=true` |

Alert if `Proven` fires but CDP/credit collateral state does not match operational expectations.

## Certora

- Specs: `certora/specs/WalletGate.spec`, `certora/specs/CdpZkFallback.spec`
- Conf: `certora/conf/WalletGate.conf`
- **Blocker:** `certoraRun` / credentials not installed here. Run before production VK cutover (same discipline as Morpho core).

## Tests

`forge test --match-contract CrownZkHardeningTest` / `CrownZkFallbackCdpTest`:

1. Malicious under-constrained shaped publics rejected (`ok!=1`, low thresh, high-bit subject, field overflow, bad vec len).
2. Broken verifier (`verifyProof=false`) rejected.
3. Fallback deposit+mint succeeds with real coll when ZK unproven; HF still enforced.

## Deploy hardened circuit (gated)

1. Rebuild `wallet_reserves.circom` → new zkey / VK (trusted setup).
2. Deploy new `Groth16WalletVerifier` + `CrownZkWalletGate`.
3. Point CDPs at new gate **or** re-attest King on existing gate if only Solidity bounds changed (bounds/fallback are Solidity-only and can ship without new VK).
4. Require `KING_GO=1` + phase flags — **no live broadcast from this agent**.
