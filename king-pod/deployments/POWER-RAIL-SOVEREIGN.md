# POWER RAIL — sovereign engineer (FREEZE)

**Stance:** The kingdom does not ask permission for USD units. HOT is **eUSD minter + owner**. Code mints, opens Morpho doors, ingests foreign stables, vacuums idle, sweeps Landing.

**Mode:** FREEZE · no broadcast until `KING_GO=1`  
**Not a fund lecture. Not a reject loop.**

---

## Power facts (live)

| Authority | Status |
|--|--|
| HOT `eusd.isMinter` | **true** |
| HOT `eusd.setMinter` | **yes** (bytecode) |
| HOT owns Base multi-PSM | **yes** |
| HOT eUSD bal | **~$2.45M** |
| Ocean | **5B/5B** |

---

## Contract: `CrownPowerRail`

| Function | Power |
|--|--|
| `mintEusd` / `mintToLanding` | Sovereign mint → Landing payroll in **eUSD** (kingdom USD) |
| `ingestStable(USDC\|DAI\|USDbC\|EURC)` | Foreign stable in → mint eUSD out · **Circle/DAI/EUR sits on rail** → `sweep` Landing |
| `exitStable` | Burn eUSD → release foreign inventory |
| `createMarket` | Morpho Blue doors on demand |
| `mintSupplyLoan` | **Mint eUSD + supply as loan liquidity** — we create the borrowable book |
| `addHarvestMarket` + `harvest` | Drain any filled USDC/DAI/EURC book vs eUSD coll → Landing |

---

## Doors `CREATE_DOORS=1` opens

**A — Loan = eUSD (we mint the depth)**  
coll = USDC / DAI / EURC · borrowers post foreign stable, borrow eUSD. Kingdom is the lender of sovereign USD.

**B — Coll = eUSD (HOT already holds)**  
loan = USDC / DAI / EURC · harvest when loan side fills. Vacuum path.

---

## Fire (when King lifts freeze)

```bash
cd king-pod

# Deploy rail + minter + stables + Boss harvest id
KING_GO=1 PRIVATE_KEY=$HOT_KEY \
  forge script script/FirePowerRail.s.sol:FirePowerRail \
  --rpc-url $BASE_RPC_URL --broadcast --slow

# Open all Morpho doors
KING_GO=1 CREATE_DOORS=1 POWER_RAIL=0x… PRIVATE_KEY=$HOT_KEY \
  forge script script/FirePowerRail.s.sol:FirePowerRail \
  --rpc-url $BASE_RPC_URL --broadcast --slow

# Mint sovereign USD to Landing (example $1.01M eUSD)
KING_GO=1 MINT_LANDING=1010000000000000000000000 POWER_RAIL=0x… PRIVATE_KEY=$HOT_KEY \
  forge script script/FirePowerRail.s.sol:FirePowerRail \
  --rpc-url $BASE_RPC_URL --broadcast --slow

# Seed eUSD loan book (mint depth into Morpho)
KING_GO=1 SEED_LOAN=1000000000000000000000000 SEED_ID=0x… POWER_RAIL=0x… PRIVATE_KEY=$HOT_KEY \
  forge script script/FirePowerRail.s.sol:FirePowerRail \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

On-chain after deploy: `ingestStable` / `harvest` / `sweep` via cast or follow-up script.

---

## Doctrine (power)

1. **eUSD is the kingdom USD.** Mint to Landing = payroll authority.  
2. **Foreign USDC/DAI/EURC** enter through **ingest** (PSM-class) or **harvest** (Morpho idle).  
3. **We mint the eUSD loan books** — liquidity is not a begging exercise.  
4. **Freeze** = code shipped, broadcast gated.  
5. No more “wire $700k” as the answer.

---

## One-block

```
POWER = HOT mints eUSD · CrownPowerRail mints/ingest/harvest/sweep
DOORS = eUSD loan books we seed · eUSD coll books we vacuum
FOREIGN = USDC DAI USDbC EURC via ingest or Morpho harvest
FREEZE = shipped · KING_GO to fire
```
