# Institutional Cash Lane — Off-Morpho Balance-Sheet Borrow

**Doctrine:** Cash from a lender’s balance sheet against pledged blue-chip collateral.  
Does not route through Elepan/USDC Morpho idle.

---

## Live Kingdom inventory (Base — verified)

| Location | WETH | cbBTC | ETH native | Notes |
|--|--|--|--|--|
| Hot | **0.002** | **0.00000378** | ~0.0023 | Dust only |
| Landing / loop / KV / CDP / vaults / seeders | **0** | **0** | dust | — |
| Sovereign CDP coll | — | — | — | **Elepan only** (~23.94M) — not WETH/cbBTC |

**Truth:** There is no multi-vault WETH/cbBTC book on the Kingdom CDP today. Blue-chip ERC20 on hot is dust. The institutional lane is still the right *architecture* — it fires when bankable BTC/ETH (or desk-accepted collateral) is pledged.

---

## Lender rails (documented)

### 1) Ledn — speed rail
| Field | Live terms |
|--|--|
| Product | Bitcoin-backed dollar loans |
| Collateral | **BTC only** (ETH loan support ended) |
| Min collateral | **~$1,000 USD equivalent BTC** |
| Min loan | **$500** |
| Typical LTV | **~50%** |
| Funding | Often within ~24h after approval |
| Payout | USD / USDC / local |
| Apply | https://www.ledn.io/bitcoin-backed-loans |

**Kingdom use:** King wires ≥$1k BTC → Ledn custody → USD/USDC out → Landing / ops.  
Independent of Morpho idle.

### 2) Galaxy GOFR — scale rail
| Field | Live terms |
|--|--|
| Product | Galaxy Onchain Financing Rate |
| Counterparty | **Galaxy** (not the underlying protocols) |
| Capital | Up to **$100M** Galaxy first-loss |
| Min loan | **$1,000,000** |
| Collateral | Native **BTC** (Galaxy wraps); desk also structures around **ETH / USDC / others** |
| Routes under the hood | Aave, Morpho, Spark, Kamino (Galaxy executes) |
| Who | Institutions / HNWI / accredited |
| Desk | https://www.galaxy.com/global-markets/lending/galaxy-onchain-financing-rate |

**Kingdom use:** Send fortress + ZK packet to Galaxy desk → structure ≥$1M against BTC/ETH or desk-accepted book → cash faces Galaxy → lands to King treasury / Landing.

---

## Kingdom underwriting packet (attach to desk)

```
Subject:        King Errick — Base fortress / institutional cash ask
Hot:            0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
Landing:        0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357
ZK Gate:        0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30  (isProven=true · $1M attest)
ZK Credit:      0xc4152c73824d85146B0f85a0b77E911D4769d936  (70% LLTV · draw→Landing)
Elepan:         0x50639C42E2FFDEC4F68FB468968a55b3Af944583
Hot Elepan:     ~55.98M liquid (post Move 1)
Morpho ELE:     ~20.0M coll · ~$14.0M borrow open
CDP:            ~23.94M Elepan · ~14.63M eUSD · HF ~1.64
yELEPAN-USDC:   0x61bf…145E · ~$14M TVL · King curator
Ask (Ledn):     size vs BTC pledged @ ~50% LTV → USDC to Landing
Ask (Galaxy):   ≥$1M structured vs BTC/ETH/desk book → USDC/USD to Landing
```

---

## Execution checklist (King GO)

| Step | Action |
|--|--|
| L1 | Confirm jurisdiction / KYC eligibility (Ledn region rules · Galaxy accredited) |
| L2 | **Ledn:** open account → apply BTC loan → transfer BTC collateral → receive USDC/USD → wire Landing |
| L3 | **Galaxy:** email/desk with packet above → negotiate ≥$1M → pledge BTC/ETH per instructions → cash to Landing |
| L4 | On USDC at Landing: optional `supply` into ZK credit is **not required** — cash already landed |

---

## How this sits with Morpho rails

| Lane | Depends on ELE idle? |
|--|--|
| Institutional Ledn / Galaxy | **No** |
| ZK credit counterparty supply | No (balance-sheet / LP supply) |
| Morpho PA / FIRE_BORROW | Yes — separate rail |

Institutional cash is an **additional automated counterparty class** in `COUNTERPARTY-AUTOMATION.md` — Rail E.
