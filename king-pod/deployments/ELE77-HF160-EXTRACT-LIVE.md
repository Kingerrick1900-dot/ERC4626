# ELE77 HF≥1.60 extract → KingVault — LIVE

**Order:** Pull supply-side, max withdraw HF≥1.60, route KingVault, confirm HF.  
**Fired:** 2026-07-29 · Base hot

## Live preflight

| Surface | Balance |
|--|--|
| ELE77 supply (hot) | ~$17.51M assets (matched) |
| ELE77 idle | **3 wei** |
| yELE hot shares | dust → **0 assets** |
| ELE77 coll | **60,000,000 ELE** |
| Borrow | ~$17.51M |
| HF before | **~3.427** |

## Ceiling (HF ≥ 1.60)

| Field | Value |
|--|--|
| Min coll @ 1.60 | ~$28.016M (28,015,791.87 ELE) |
| Max ELE withdraw | **~31,984,208.13 ELE** |
| Max USDC supply withdraw | **3 wei** (idle cap) |

## Executed

| Field | Result |
|--|--|
| ELE → KingVault | **31,984,208.130252 ELE** |
| USDC → KingVault | **3 wei** |
| Coll after | **~28,015,791.87 ELE** |
| Borrow after | unchanged (~$17.51M + accrued) |
| **HF after** | **1.600000057** (≥ 1.60) |

KingVault: `0xA1aFcb46a64C9173519180458C1cF302179c832a`

## Note

yELE had no withdrawable assets. ELE77 USDC supply could not move beyond idle dust. Real extract under the HF floor was **collateral ELE** to the 1.60 ceiling.

Status: `ELE77_HF160_EXTRACT_OK`  
Broadcast: `king-pod/broadcast/FireEle77Hf160Extract.s.sol/8453/run-latest.json`
