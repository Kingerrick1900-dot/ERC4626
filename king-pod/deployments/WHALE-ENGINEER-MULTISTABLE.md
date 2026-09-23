# WHALE ENGINEER — multi-stable Morpho harvest (FREEZE-ready · FIRE-gated)

**Team posture:** a16z / whale. Code engineers Circle, DAI, USDbC, EURC, cbBTC-loan capacity by **borrowing foreign idle** against collateral the kingdom controls or funds. Nobody mints USDC in Solidity — Morpho already wrote the playbook; we industrialize it.

**Mode:** FREEZE default · `KING_GO=1` to broadcast  
**Branch kit:** `CrownWhaleHarvest` · `MorphoPegOracle` · `CreateEusdLoanMarkets` · `FireWhaleHarvest` · `whale_universe_scan.py`

---

## What we shipped

| Artifact | Role |
|--|--|
| `CrownWhaleHarvest.sol` | Register ≤32 Morpho markets · `harvest` / `vacuumAll` · loan → Landing |
| `MorphoPegOracle.sol` | Peg oracles for eUSD×{USDC,DAI,USDbC} market creation |
| `CreateEusdLoanMarkets.s.sol` | Permissionless Morpho `createMarket` — eUSD coll doors for multi-stable loans |
| `FireWhaleHarvest.s.sol` | Deploy harvest · wire Boss + cbBTC/USDC + WETH/USDC + USDe/USDC · optional vacuum |
| `whale_universe_scan.py` | Live idle board → `deployments/whale-universe.json` |

---

## Live Base idle (order of magnitude · re-scan before fire)

| Loan | Coll | Idle (approx) | Use |
|--|--|--|--|
| **USDC** | **cbBTC** | **~$161M** | Fund cbBTC → `harvest(MKT_CBBTC_USDC)` |
| **USDC** | **USDe** | **~$36M** | If kingdom holds USDe |
| **USDC** | **WETH** | **~$9.5M** | Fund WETH → harvest |
| **USDC** | eUSD (Boss) | dust | Vacuum on refill |
| **DAI / USDbC / EURC** | — | create eUSD doors, then attract/fill | `CreateEusdLoanMarkets` |

Scan:

```bash
python3 king-pod/script/whale_universe_scan.py
```

---

## Fire sequence (whale)

### 1) Open eUSD loan doors (multi-stable)

```bash
cd king-pod
KING_GO=1 PRIVATE_KEY=$HOT_KEY \
  forge script script/CreateEusdLoanMarkets.s.sol:CreateEusdLoanMarkets \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

Creates Morpho markets: **eUSD→USDC**, **eUSD→DAI**, **eUSD→USDbC**, **eUSD→EURC** @ 86% LLTV + peg oracle.  
Then: list in MetaMorpho / PA packet / rate magnet so foreign stables fill the loan side. When idle > 0 → harvest.

### 2) Deploy universal vacuum

```bash
KING_GO=1 PRIVATE_KEY=$HOT_KEY \
  forge script script/FireWhaleHarvest.s.sol:FireWhaleHarvest \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

Registers:

- Boss eUSD/USDC  
- cbBTC/USDC (`0x9103…`) · **~$161M** idle  
- WETH/USDC (`0x8793…`) · **~$9.5M**  
- USDe/USDC (`0x54cf…`) · **~$36M**  
- cbBTC/EURC (`0x67eb…`) · **~$607k** euro door

Approves eUSD, cbBTC, WETH on HOT → harvest.

### 3) Vacuum whenever idle exists

```bash
KING_GO=1 VACUUM=1 HARVEST=0x<harvest> PRIVATE_KEY=$HOT_KEY \
  forge script script/FireWhaleHarvest.s.sol:FireWhaleHarvest \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

Or single book:

```bash
KING_GO=1 HARVEST=0x… HARVEST_ID=0x9103… HARVEST_MAX=0 PRIVATE_KEY=$HOT_KEY \
  forge script script/FireWhaleHarvest.s.sol:FireWhaleHarvest \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

### 4) Bluechip capital → max USDC

| Capital on HOT | Action |
|--|--|
| **cbBTC** ≳ $1.175M notional | `harvest(cbBTC/USDC)` → Landing USDC @ 86% |
| **WETH** sized to ask | `harvest(WETH/USDC)` |
| **eUSD** + Boss/eUSD-door idle | `harvest(Boss)` / new eUSD doors |
| **Spendable USDC** | Landing transfer (payroll) — harvest not required |

---

## Engineering doctrine (elite, not theater)

1. **Borrow > swap fantasy.** Empty Aero eUSD/USDC is not a whale door; Morpho idle books are.  
2. **Coll is the key.** eUSD we mint/hold; cbBTC/WETH we fund or OTC.  
3. **Create markets** when loan asset has no eUSD door — then **fill** (vault listing / self-seed / magnet).  
4. **Vacuum is a cron.** Same calldata, refill → drain → Landing.  
5. **Keep eUSD.** Prefer borrow-vs-eUSD over dumping the peg asset.  
6. **Freeze gate.** No broadcast without `KING_GO=1` + HOT key.

---

## One-block

```
WHALE = CrownWhaleHarvest vacuum Morpho idle → Landing
DOORS = create eUSD×{USDC,DAI,USDbC} markets + list/fill
DEEP = cbBTC/USDC ~$161M · WETH/USDC ~$9.5M — fund coll → harvest
SCAN = python3 script/whale_universe_scan.py
FIRE = KING_GO=1 only
```
