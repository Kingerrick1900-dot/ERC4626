# Elepan Core — LIVE on Base

**Fired:** oracles + Morpho markets + flash seeder (matched books) + yELEPAN-WETH vault + Elepan ZK attestation

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
| Market Elepan/cbBTC | `0x28d57b898122465e0260881973440823f1a380d64f16af56d982b47e5aeffa25` |
| Market Elepan/WETH | `0xac7c17fa240d82d89268b5307971144970fe9be0ea45ed7d6bcb707e33b7ed44` |
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

## ZK attestation — Elepan wallet-bind (LIVE)

See `ZK-ELEPAN-BIND.md`. Gate `isProven(hot)=true`, threshold **$700k**, proof tx `0xe5630deb…771d88`.

| Piece | Address |
|--|--|
| Verifier (reused RSS) | `0xbb3C589E7451087290B56578f19bf08C7b1Fc17B` |
| CrownZkElepanGate | `0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30` |
| CrownZkElepanCredit (private vault rail) | `0xc4152c73824d85146B0f85a0b77E911D4769d936` |

## Law
Self-seed = depth (matched books ≠ free capital). Pay from fee/idle/external only.
Zama FHE encrypted balances = **next** (rail live; FHE deferred).
