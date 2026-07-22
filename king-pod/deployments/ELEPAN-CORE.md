# Elepan Core — Morpho markets (LIVE path)

**Token:** ElepanToken `0x50639C42E2FFDEC4F68FB468968a55b3Af944583` (8dp, hot **100M**)  
**Main pair:** Elepan → borrow **cbBTC**  
**Second:** Elepan → borrow **WETH**  
**Peg:** Soft **$1** Elepan × UniV3 TWAP loan/USDC (cbBTC-backed thesis; fixed $1 until reserve feed wired)

## Stack

| Piece | Role |
|--|--|
| `MorphoFixedElepanLoanOracle` | Elepan@$1 × loan/USDC TWAP |
| Morpho Blue markets | Elepan/cbBTC (main), Elepan/WETH |
| `yELEPAN-cbBTC` MetaMorpho | 10% fee, curator=hot, queue=cbBTC market |
| `CrownElepanFatFlashSeed` | Optional flash depth (Kingdom debt books) |

## Fire

### 1) Oracles + markets + vault (no seed debt)

```bash
cd king-pod
KING_GO=1 FIRE=1 \
  forge script script/FireElepanCore.s.sol:FireElepanCore \
  --rpc-url $RPC --broadcast --slow -vvvv
```

Save printed: `Oracle Elepan/cbBTC`, `Oracle Elepan/WETH`, market ids, vault, seeder.

### 2) Flash-seed depth (optional — creates Morpho debt)

```bash
KING_GO=1 FIRE=1 FIRE_SEED=1 \
  ORACLE_CBTC=<addr> ORACLE_WETH=<addr> SEEDER=<addr> VAULT=<addr> \
  FLASH_CBTC=50000000 FLASH_WETH=10000000000000000000 \
  forge script script/FireElepanCore.s.sol:FireElepanCore \
  --rpc-url $RPC --broadcast --slow --gas-estimate-multiplier 200
```

Defaults: **0.5 cbBTC** + **10 WETH** matched books, HF_raw ≥ 1.55.

## Law

- Self-seed = **depth / curator magnet**, not free loan-asset profit.  
- Pay King from **fee + idle + external** only.  
- Soft seat ~48% LTV when sizing larger seeds (raise coll).  

## Next

ZK re-bind on Elepan hot · WETH MetaMorpho · backing-ratio oracle upgrade when cbBTC reserves address is named.
