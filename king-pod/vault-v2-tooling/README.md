# Vault V2 tooling (King)

Scripts/tests here target Morpho's `vault-v2-deployment` Foundry project (solc 0.8.28 + vault-v2 lib).

Copy into a clone of https://github.com/morpho-org/vault-v2-deployment before running.

| File | Purpose |
|------|---------|
| `test/KingRssForceDeallocateExit.t.sol` | Fork-prove `forceDeallocate` exit ×2 (fresh deploy path) |
| `test/LiveVaultForceDeallocateExit.t.sol` | Fork-prove exit ×2 on **live** vault `0xB96B…A7b9` |
| `script/DeployKingVaultV2.s.sol` | Live deploy — **requires `LIVE_ARMED=1`** |

See `../deployments/VAULT-V2-FORK-PASS.md`.
