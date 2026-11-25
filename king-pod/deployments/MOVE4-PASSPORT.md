# Move 4 — cbBTC / WETH Morpho Passport

**Mode:** BUILD · dry-run green · **broadcast gated on blue-chip seed**  
**Doctrine:** Lead with Coinbase-grade collateral. Borrow foreign USDC idle. Fund KingVault.

---

## Physics

| Step | Action |
|--|--|
| 1 | HOT holds **cbBTC** or **WETH** (equity — not flash-bought) |
| 2 | Optional: PublicAllocator fills **that** Morpho market (foreign vaults → market idle) |
| 3 | `supplyCollateral` on canonical Base Morpho USDC book (86% LLTV) |
| 4 | `borrow` USDC → **KingVault** `0xA1aF…832a` |

PublicAllocator does **not** move foreign idle into ySYNTH. Idle is borrowed **on the blue-chip market**.

---

## Live board (2026-11-25 PT)

| Item | Value |
|--|--|
| HOT cbBTC | **dust** (~4e-6) |
| HOT WETH | **0** |
| HOT USDC | **0** |
| HOT eUSD | 3,000,000,000 (not blue-chip passport) |
| cbBTC/USDC market idle | **hundreds of $M** (REST) |
| WETH/USDC market idle | **tens of $M** (REST) |
| Fire ready? | **NO** — seed collateral first |

---

## Markets (Base)

| Asset | Market ID | Oracle | LLTV |
|--|--|--|--|
| cbBTC/USDC | `0x9103c3b4…1836` | `0x663BEC…9B9` | 86% |
| WETH/USDC | `0x8793cf30…1bda` | `0xFEa2D5…FE4` | 86% |

---

## Code delivered

| File | Role |
|--|--|
| `src/CrownPassportBorrow.sol` | HOT-gated module (needs Morpho authorization) |
| `script/DeployPassportBorrow.s.sol` | Deploy + arm |
| `script/FireMove4Passport.s.sol` | Direct HOT fire or via module |
| `offchain/move4_passport.py` | Inventory + idle gate; dry default |

### Commands

```bash
cd king-pod
# Board read (expected NOOP until seed):
python3 offchain/move4_passport.py

forge script script/FireMove4Passport.s.sol:FireMove4Passport --rpc-url $RPC -vv

# After King seeds >= 0.001 cbBTC (or WETH) on HOT:
ASSET=cbbtc BORROW_AMT=100000000000 BROADCAST=1 PRIVATE_KEY=0x... \
  forge script script/FireMove4Passport.s.sol:FireMove4Passport --rpc-url $RPC --broadcast

# Optional module:
forge script script/DeployPassportBorrow.s.sol:DeployPassportBorrow --rpc-url $RPC --broadcast
# then Morpho.setAuthorization(passport, true) from HOT
```

---

## Seed options (King)

1. Desk / OTC: park cbBTC or WETH on HOT  
2. Hunt inventory → `CrownExitNative.fundInventory` → exit path (inventory currently **0**)  
3. External USDC → buy blue-chip → passport (if King brings USDC)

**Forbidden:** flash-buy collateral hoping borrow repays flash (LTV < 100% → revert). Same accounting lesson as the $30M sequence.

---

## Scoreboard

```
MOVE=4 passport
MODULE=CrownPassportBorrow (pending deploy)
FIRE=gated
BLOCKER=HOT blue-chip ~0
IDLE=cbBTC/WETH markets deep
NEXT=seed cbBTC|WETH on HOT -> FireMove4Passport -> KingVault USDC
THEN=Move 5 scale
```
