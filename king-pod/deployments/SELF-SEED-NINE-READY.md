# SELF-SEED $9M — READY TO FIRE

## King’s Moves (as engineered)

| Move | Intent | Engineered path |
|--|--|--|
| **1** | Post 18.5M RSS, borrow $9M @ ≤70% LTV | Atomic with Move 2 (market idle is ~$1 — cannot borrow $9M spot) |
| **2** | Seed yRSS with that $9M, RSS market self-funded | Flash USDC → `yRSS.deposit` → Morpho `borrow` → repay flash |

**One tx stack.** No Gauntlet. No Steakhouse. No OTC.

## Sim result (Base fork) — PASS

```
coll            18,499,999.999999978 RSS
marketSupply    ~$9,000,001
marketBorrow    $9,000,000
yRSS_TVL        ~$9,000,001
hotYrssAssets   ~$9,000,001
hotUsdc         ~$1.00 (floor kept)
LTV             ~48.6% (under 70% cap)
HF vs 77% LLTV  ~1.58
```

## End state (what you get)

- **18.5M RSS** posted as Morpho collateral  
- **$9M** Morpho debt  
- **$9M yRSS shares** on hot (the war chest / vault TVL)  
- **KingVault** 10% fee rail on yRSS interest  
- Wallet liquid USDC stays ~$1 — flash closes; chest is **yRSS**, not loose USDC  

## Fire command (ONLY when King says go)

```bash
cd king-pod
FIRE=1 BORROW_USDC=9000000000000 \
  forge script script/FireSelfSeedNine.s.sol:FireSelfSeedNine \
  --rpc-url $BASE_RPC_URL --broadcast --slow --gas-estimate-multiplier 200
```

Prep-only (deploy + auth + approve, no seed):

```bash
FIRE=0 forge script script/FireSelfSeedNine.s.sol:FireSelfSeedNine \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

## Contracts / knobs

| | |
|--|--|
| `CrownSelfSeedNine` | `src/CrownSelfSeedNine.sol` |
| Script | `script/FireSelfSeedNine.s.sol` |
| `FIRE=1` | execute `selfSeed` |
| `BORROW_USDC` | raw USDC (default `9000000000000`) |
| `SEEDER` | reuse deployed seeder address |

## REPAY_SOURCE (flash policy)

`Morpho.borrow(RSS market, onBehalf=hot)` against posted RSS, after `yRSS.deposit` created idle USDC in-market.
