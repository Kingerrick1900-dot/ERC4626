# Elepan Core — LIVE on Base

**Fired:** oracles + Morpho markets + flash seeder + yELEPAN-WETH + **moat + yELEPAN-USDC** + Elepan ZK attestation

## Token
| | |
|--|--|
| ElepanToken | `0x50639C42E2FFDEC4F68FB468968a55b3Af944583` (8dp) |
| Hot free | ~**99.92M** (seed coll posted on Morpho) |
| Peg | Soft **$1** × Uni TWAP loan/USDC |

## Morpho markets

| Piece | Address / Id |
|--|--|
| Oracle Elepan/cbBTC (**main**) | `0x08DEeEF782B81C8CDD2e11bF5a54982f3A11C94d` |
| Oracle Elepan/WETH | `0xF927B35E62A0111Da1A5D4Da63FA57E473B525E5` |
| Oracle Elepan/USDC (**moat**) | `0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19` (fixed 1e34) |
| Market Elepan/cbBTC | `0x28d57b898122465e0260881973440823f1a380d64f16af56d982b47e5aeffa25` |
| Market Elepan/WETH | `0xac7c17fa240d82d89268b5307971144970fe9be0ea45ed7d6bcb707e33b7ed44` |
| Market Elepan/USDC (**moat**) | `0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc` |
| LLTV | **77%** |
| IRM | AdaptiveCurve `0x46415998764C29aB2a25CbeA6254146D50D22687` |
| CrownElepanFatFlashSeed | `0x24622EB06a9593BCd608656e2dcfecA9075c4688` |

### Seeder (Morpho flash callback)
Implements `IMorphoFlashLoanCallback`. In `onMorphoFlashLoan`: **supply loan → supplyCollateral Elepan → borrow → approve repayment**. Any failure reverts the whole flash (nothing sticks).

### Seed books (LIVE)
| Market | Supply = Borrow | Elepan coll (hot) |
|--|--|--|
| cbBTC | **0.5 cbBTC** | ~51.7k |
| WETH | **10 WETH** | ~30.2k |

Seed txs: `0x8b20753c…a3353f` (cbBTC), `0x33e2a897…8d66f6` (WETH)

## Vault — yELEPAN-WETH (LIVE)

WETH-primary MetaMorpho (cbBTC vault deferred). Curator=hot, fee=10%, timelock=**2 days**, queue=Elepan/WETH.

| Piece | Value |
|--|--|
| Vault | `0xfdD5a1d4823411809D6ac735991B3A015E5AaAb5` |
| Asset | WETH |
| Supply cap | **20_000 WETH** (~50M Elepan coll capacity @ ~$2k ETH × 77% LLTV) |
| PA | `0xA090dD1a701408Df1d4d0B85b716c87565f90467` |
| PA flow caps | maxIn=maxOut=**20_000 WETH** |
| Create tx | `0x20c74912…2809ae` |

```bash
# Reconfigure / re-arm (vault already live — pass VAULT=)
KING_GO=1 FIRE_VAULT=1 VAULT=0xfdD5a1d4823411809D6ac735991B3A015E5AaAb5 \
  forge script script/FireElepanVaultWeth.s.sol:FireElepanVaultWeth \
  --rpc-url $RPC --broadcast --slow --skip-simulation
```

## Moat + yELEPAN-USDC (LIVE) — like yRSS

See `ELEPAN-MOAT.md`. Soft $1 Elepan/USDC book + USDC MetaMorpho (14M cap, 700k PA, 10% → Landing, 2d timelock).

| Piece | Value |
|--|--|
| Oracle Elepan/USDC | `0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19` |
| Market Elepan/USDC | `0xa4ec5271…da53fc` |
| yELEPAN-USDC | `0x61bfD6F7df1f72427F472144d043c25d742D145E` |

## ZK attestation — Elepan wallet-bind (LIVE)

See `ZK-ELEPAN-BIND.md`. Gate `isProven(hot)=true`, threshold **$700k**, proof tx `0xe5630deb…771d88`.

| Piece | Address |
|--|--|
| Verifier (reused RSS) | `0xbb3C589E7451087290B56578f19bf08C7b1Fc17B` |
| CrownZkElepanGate | `0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30` |
| CrownZkElepanCredit (private vault rail) | `0xc4152c73824d85146B0f85a0b77E911D4769d936` |

## Vault V2 (adapter path) — LIVE
See `ELEPAN-VAULT-V2.md`. Vault `0x35a00F116536c13A63273513990E4E496a15Ddb2` + adapter `0x384A596C…F585`. Caps use `uint128.max` via submit→exec.

## System-funded rail — LIVE
See `SYSTEM-FUNDED-RAIL.md`.
- FHE v2 `0x761C50d4…Bb0B` + sleeve `0xc5084FAB…FBBC` (USDC→WETH→MM/V2)
- V2 fees: 10% perf + 1%/yr mgmt → hot; gates `0x0`

## Self-seed + copy-cat loop — PLAN ONLY
See `ELEPAN-SELF-SEED-PLAN.md`. M1 magnet (yRSS-style) + M2 copy-cat (deposit→borrow→redeploy→repeat, MORE/Coinbase-shaped). **No fire until King GO + phase + size.**

## Curator allocation + loan access — VERDICT
See `ELEPAN-CURATOR-ACCESS.md`. **Yes:** allocate at TVL=0. Blue borrows stay permissionless; caps/PA/V2 gates = full or partial *liquidity/deposit* access. No config fire in that note.

## Paying self-seed — PLAN ONLY (Apollo / aarnâ copy)
See `ELEPAN-PAY-SEED.md`. Gold standard: **ACRED-style coll→borrow→spread** + **âtvUSDC-style loop only when carry+** (target band ~8–12% when rates clear). Circular FeeSeed demoted. **No fire until GO.**

## Law
Self-seed = depth (matched books ≠ free capital). Pay from fee/idle/external only.
Zama FHE encrypted balances = **next** (rail live; FHE deferred).
