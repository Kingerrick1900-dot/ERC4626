# Grok Phase 1 — LIVE (tranche)

**Status: FIRED on Base · ONCHAIN SUCCESS**

Full $13M ask blocked by coll on hot (Landing still holds ~76M Morpho-ELE). Auto-sized to HF ≥ 1.55 max.

## End state
| Field | Value |
|--|--|
| Seeder | `0xb71FBCf68e5446f4b96a016C5fF259332dC5eC5e` |
| Morpho ELE coll (hot) | **1,230,007.31** |
| Morpho USDC debt | **~$793,353.72** |
| HF (soft $1) | **1.5504** |
| LTV | **64.50%** |
| yELEPAN-USDC TVL | **~$793,353.75** |
| Earn shares (Landing) | `528874459062342157437453` |
| KingVault liquid USDC | $0 (matched flash close — earn leg = yELE shares) |
| Hot free ELE | **0** (all posted) |

## Txs
| Step | Hash |
|--|--|
| Deploy `CrownElepanGrokPhase1` | `0xef91a5cfde5b907ac631b4325bf4d2ed6f9d8dd8c335718c9b6794612a88a15d` |
| Morpho `setAuthorization` | `0x9de1f5eef0268bf90b86e2e6b087c5cb251f58382d8c32cb86f104dc99c0e8a0` |
| Elepan `approve` | `0x143dce1758be9f98af2a9461d0f58c1cbfad96f7ef1d933673cd650eea89cf61` |
| `phase1` self-seed | `0xc009a71a9ab8a846570ddae0e2aee78e7941bc0227ffe41b204ced614f4cd3ac` |

## Path
```
flash Morpho USDC → yELE.deposit → borrow vs Elepan → repay flash
REPAY_SOURCE = Morpho.borrow(ELE/USDC)
```

## GO board
| | |
|--|--|
| Phase 1 tranche | **GO · FIRED** HF 1.55 |
| Full $13M | **NO** — need ≥ ~20.16M Morpho-ELE (`0x50639…4583`) on hot |
| Phase 2 WETH/cbBTC | Already looped (prior) |
| Fees | `submitFee` revert on vault; recipient arm follow-up |

## Upsize to $13M
Move Morpho-ELE `0x50639C42E2FFDEC4F68FB468968a55b3Af944583` from Landing `0x5Adc…` → hot, then re-fire with `BORROW_USDC=13000000000000`.
