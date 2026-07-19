# Vault V2 — fork PASS, live BLOCKED

**Status:** Fork exit proven.  
**Note:** A live deploy **did land** before the stop fully locked — see `VAULT-V2-LIVE.md`. No further live txs after King’s order.

## Landing wallet

`0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` — final V2 owner / exit destination.

Hot (ops curator/allocator signer): `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1`

## Fork proof (PASS ×2)

Contract: `KingRssForceDeallocateExit`

| Check | Result |
|-------|--------|
| Deploy V2 + MorphoMarketV1 adapter on Base fork for RSS/USDC market | PASS |
| Owner = landing | PASS |
| `forceDeallocate` penalty = 1% | PASS |
| Normal withdraw at ~100% util reverts | PASS |
| Flash-style supply → `forceDeallocate` → withdraw to landing | PASS ×2 ($10k, $25k seeds) |

Market: `0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794`  
IRM: `0x46415998764C29aB2a25CbeA6254146D50D22687` (matches adapter)

## What live deploy will do (when armed)

Script: `vault-v2-tooling/script/DeployKingVaultV2.s.sol`

- Owner → **landing**
- Curator / allocator → **hot** (and landing also allocator)
- RSS/USDC liquidity adapter + uncapped private caps
- `forceDeallocate` penalty **1%**
- Timelock **0** (private access vault; not Morpho-app listing)
- Tiny $1 dead seed only if deployer has ≥$1 USDC — **not** the Morpho listing $1M dead deposit
- **Hard gate:** `LIVE_ARMED=1` required or script reverts `NO-LIVE`

## Run fork proof

```bash
git clone https://github.com/morpho-org/vault-v2-deployment /tmp/vault-v2-deployment
cd /tmp/vault-v2-deployment && forge install
cp /path/to/king-pod/vault-v2-tooling/test/KingRssForceDeallocateExit.t.sol test/
cp /path/to/king-pod/vault-v2-tooling/script/DeployKingVaultV2.s.sol script/
forge test --match-contract KingRssForceDeallocateExit --fork-url $RPC_URL -vv
```

## Live (King only)

```bash
# ONLY after King green light:
LIVE_ARMED=1 PRIVATE_KEY=... forge script script/DeployKingVaultV2.s.sol \
  --rpc-url $RPC_URL --broadcast -vvvv
```

Simulation without arming / without `--broadcast` is fine anytime.

## Policy

- Access ≠ outside capital. `forceDeallocate` proves **unwind access** at 100% util; it does not create outside TVL.
- No recycle of freed RSS into Morpho/Pod/yRSS until exit is live-proven (`NO-RECYCLE-UNTIL-EXIT.md`).
- Cake retired. Do not use Cake.
- **Scribe: no live green light until the King says.**
