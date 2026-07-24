# Curator Packet — Elepan/USDC (send today)

**One ask:** enable Public Allocator `maxIn` on Morpho Blue **Elepan/USDC** so idle USDC can reach this market.  
King posts Elepan collateral and borrows USDC → **Landing KEEP** (no vault recycle).

---

## Market (Base)

| Field | Value |
|--|--|
| Market id | `0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc` |
| Loan | USDC `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| Collateral | Elepan `0x50639C42E2FFDEC4F68FB468968a55b3Af944583` (8dp) |
| Oracle | Fixed ~$1 `0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19` |
| IRM | AdaptiveCurve `0x46415998764C29aB2a25CbeA6254146D50D22687` |
| LLTV | **77%** |
| Morpho | `0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb` |

**Live market state (post clean-up):** supply / borrow ≈ **$0** · idle ≈ **$0** — empty book ready for real external liquidity.

---

## Ask (copy into PA / vault config)

On **your** MetaMorpho USDC vault, set flow caps for market id above:

| Field | Request |
|--|--|
| `maxIn` | **$700,000** first · scale to **$5,000,000** |
| `maxOut` | match your vault risk policy |

Public Allocator (Base): `0xA090dD1a701408Df1d4d0B85b716c87565f90467`

On first `maxIn > 0` with idle that can reallocate in, King fires:

```bash
KING_GO=1 FIRE_BORROW=1 \
  forge script script/FireElepanBorrowUsdc.s.sol:FireElepanBorrowUsdc \
  --rpc-url $BASE_RPC --broadcast --slow
```

USDC lands on **Landing** `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` — **KEEP**, not re-deposited into yELE.

---

## Why this borrower

| Line | Live |
|--|--:|
| Free Elepan (Landing) | **~75.98M** |
| CDP Elepan posted | **~23.94M** (separate; HF ~1.64) |
| Morpho ELE position (hot) | **0 coll / 0 debt** (self-loop unwound) |
| Soft borrow capacity @ 70% of free ELE @ $1 | **~$53M** theoretical |
| First ask | **$700k** (conservative tranche) |

Oracle is fixed $1 (burned-owner pattern). Isolated market. No circular self-seed: prior matched loop was closed; draw path is collateral → borrow → Landing.

---

## Kingdom vault (context — not the ask)

| Field | Value |
|--|--|
| Vault | yELEPAN-USDC `0x61bfD6F7df1f72427F472144d043c25d742D145E` |
| Name | King Elepan USDC Vault |
| Owner / curator | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| Market cap (this id) | **$14,000,000** |
| Own PA flowCaps (yELE ↔ this market) | **$700k / $700k** already set |
| Vault TVL now | **dust** (loop redeemed) |

**Ask is to external curators** (Gauntlet / Steakhouse / Moonwell / Spark / Yearn) to open `maxIn` **from their vaults into this market** — not to configure yELE.

---

## Targets (Base USDC MetaMorpho)

| Vault | Address | TVL class |
|--|--|--|
| Gauntlet USDC Prime | `0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61` | ~$428M |
| Steakhouse Prime USDC | `0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2` | ~$229M |
| Steakhouse USDC | `0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183` | ~$183M |
| Moonwell Flagship USDC | `0xc1256Ae5FF1cf2719D4937adb3bbCCab2E00A2Ca` | ~$9M |
| Spark USDC | `0x7BfA7C4f149E7415b73bdeDfe609237e29CBF34A` | ~$6.7M |
| Yearn OG USDC | `0xef417a2512C5a41f69AE4e021648b69a7CdE5D03` | ~$2.0M |
| Gauntlet USDC Core | `0xc0c5689e6f4D256E861F65465b691aeEcC0dEb12` | ~$1.9M |

---

## Email / Discord paste

```
Subject: PA maxIn request — Morpho Base Elepan/USDC (77% LLTV)

Market id:
0xa4ec527128b425ee3fcb7f60eca37677b63b3d003345ec2a72ef6a2e72da53fc

Loan: USDC 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
Coll: Elepan 0x50639C42E2FFDEC4F68FB468968a55b3Af944583
Oracle: 0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19 (fixed $1)
IRM: 0x46415998764C29aB2a25CbeA6254146D50D22687
LLTV: 77%

Ask: set Public Allocator flowCaps maxIn = $700k (scale later to $5M)
PA: 0xA090dD1a701408Df1d4d0B85b716c87565f90467

Borrower: 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
Receive USDC: 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357 (Landing KEEP)

Collateral ready: ~76M free Elepan on Landing + clean Morpho book (0/0).
No self-seed / vault recycle on draw.

Packet: CURATOR-PACKET-ELE-USDC.md in Kingdom repo.
```

---

## Related rails (not this packet)

| Rail | Status |
|--|--|
| ZK credit supply → Landing | Credit `0xc415…d936` · pool USDC **$0** until supplier |
| eUSD → dollars | Needs PSM / pool / buyer — see `EUSD-TO-DOLLARS.md` |
| Institutional (Ledn / Galaxy) | BTC/ETH balance-sheet — see `INSTITUTIONAL-CASH-LANE.md` |
