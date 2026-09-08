# CROWN VAULT SOLVER — LIVE

**Status:** DEPLOYED + FIRED on Base  
**Branch:** `cursor/crown-vault-solver-4f7f`  
**Law:** No flash. Keep 80% / peel 20%.

---

## Live addresses

| Piece | Address |
|--|--|
| **CrownVaultSolver** | `0x4DFfb070323e509dd4B87E5EB39492B6452c2337` |
| Landing | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| eUSD Morpho market | `0x5d46483aa8dda7876be78f42f1fe2c93856918e26ed027ad4bb551cb74a68366` |
| eUSD oracle | `0x44bc82a9ADaF15edCa1bc0030Bdf7500af5CC750` |
| HOT | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |

---

## First fire (dust proof)

| | |
|--|--|
| Seed | **$1.000070** USDC (all HOT dust) |
| Borrow | **$1.000070** |
| **Peel → Landing** | **$0.200014** |
| Keep → book | **$0.800056** |
| Morpho idle left | **$0.800056** |
| HOT Morpho coll | **40M eUSD** (unchanged) |
| `willFromZero` tx | `0xdb57e8cb012d43efc59e6eb1c436a62cf5767878e576bd351b63d099ad54fe0e` |

Physics: supply $1.80 / borrow $1.00 / Landing cash real. Not ghost debt.

---

## Deploy

```bash
KING_GO=1 CREATE_GUSD_MKT=0 \
  forge script script/FireCrownVaultSolver.s.sol:FireCrownVaultSolverDeploy \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

## Next Fibonacci peels

```bash
# willLoop on remaining idle (~$0.80 → peel ~$0.16)
cast send 0x4DFfb070323e509dd4B87E5EB39492B6452c2337 \
  "willLoop(uint256)" 0 \
  --private-key $PRIVATE_KEY --rpc-url $BASE_RPC_URL
```

Larger seeds: fund HOT USDC → `FireWillFromZero` with `SEED_USDC` + optional `EUSD_COLL` / `GUSD_COLL`.

---

## Safety

- `armed=true` · peelBps=2000 · Morpho `isAuthorized(HOT, solver)=true`
- credit unset (peel → Landing direct)
- **Rotate HOT key** — was used in chat

## Tests

```bash
forge test --match-contract CrownVaultSolverTest -vv   # 6/6
```
