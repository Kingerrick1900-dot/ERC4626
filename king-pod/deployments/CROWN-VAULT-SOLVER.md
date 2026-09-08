# CROWN VAULT SOLVER — willFromZero

**Branch:** `cursor/crown-vault-solver-4f7f`  
**Law:** No flash. Own vault + exclusive solver. Keep 80% / peel 20%.

---

## What it is

`CrownVaultSolver` — one contract that is **lender, borrower, and bank**.

| Step | Action |
|--|--|
| 1 | King seeds USDC → vault |
| 2 | Vault supplies USDC into **owned** eUSD/USDC Morpho book |
| 3 | Posts **dual coll** (eUSD + optional gUSD) on behalf of king |
| 4 | Borrows against that coll |
| 5 | **80% keep** → re-supply book (fat) |
| 6 | **20% peel** → Landing (or CrownPrimeCredit if wired) |

`willLoop` repeats on remaining idle (Fibonacci peels) without new seed.

---

## Base constants

| | |
|--|--|
| HOT | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| Landing | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| Morpho | `0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb` |
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| eUSD | `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a` |
| gUSD | `0x319A49BB274A826F889C6e7221FA82f24ac8bc5d` |
| eUSD market (live) | `0x5d46483aa8dda7876be78f42f1fe2c93856918e26ed027ad4bb551cb74a68366` |
| Optional credit | `0x5568fE662363d7F3fa52349A99C9e19C6616B60d` |

---

## Deploy (no fire)

```bash
cd king-pod
KING_GO=1 CREDIT=0x5568fE662363d7F3fa52349A99C9e19C6616B60d \
  forge script script/FireCrownVaultSolver.s.sol:FireCrownVaultSolverDeploy \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

HOT must `setAuthorization(solver, true)` on Morpho (script does this). Approve USDC/eUSD/gUSD to solver before fire.

---

## Fire willFromZero

```bash
KING_GO=1 FIRE_WILL=1 \
  VAULT_SOLVER=0x… \
  SEED_USDC=1000000000000 \
  EUSD_COLL=40000000000000000000000000 \
  GUSD_COLL=100000000000000000000000000 \
  forge script script/FireCrownVaultSolver.s.sol:FireWillFromZero \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

`$1M seed` → peel **$200k** Landing · keep **$800k** book.  
Next `willLoop`: peel **$160k** · keep **$640k**. Books fatter, payroll real.

---

## Safety

- `armed=false` freezes willFromZero / willLoop  
- peelBps locked **5%–50%** (default 20%) — no 100% recycle ghost path  
- `repayEusd` — king self-repay anytime  
- No flash loan code path  

---

## Tests

```bash
forge test --match-contract CrownVaultSolverTest -vv
```
