# Tenor → Armitage RFQ — $700k USDC facility

**Status:** CODE-FIRST READY  
**Primary key:** Tenor OTC `createQuoteInquiry` → **Armitage by Wintermute**  
**App:** https://app.tenor.finance/otc  
**API:** https://api.tenor.finance/graphql  
**Packet:** `tenor-armitage-rfq-700k.json`

## Why this door

Tenor is live on Base on Morpho Midnight. Borrowers RFQ offchain; lenders (Armitage) return **onchain** lend offers. Settlement is Morpho — not Steakhouse email hope. Armitage org id confirmed live:

`123cf521-4b9e-4b58-9335-d6d0b35f8b95` — **Armitage by Wintermute**

ELE (`0x50639…4583`, 8dp, Tenor symbol RSS) is already in Tenor’s token registry.

## Ask

| Field | Value |
|--|--|
| Borrow | **$700,000 USDC** (`700000000000`) |
| Collateral | ELE `0x50639C42E2FFDEC4F68FB468968a55b3Af944583` |
| Suggested oracle / LLTV | `0xe290…cf19` / 77% (lender may reprice) |
| Term window | 7–30 days |
| Receiver / ops | Hot `0x6708…a7d1` → Landing `0x5Adcea…2357` |
| Fortress | Free ELE + Morpho ELE coll + ZK gates proven |

## Fire (code-first)

```bash
# 1) Build + print exact GraphQL RFQ (no auth)
python3 king-pod/script/FireTenorArmitageRfq.py --print-only

# 2) Connect hot on https://app.tenor.finance → copy session Bearer/cookie
# 3) POST inquiry to Armitage
TENOR_BEARER=... python3 king-pod/script/FireTenorArmitageRfq.py --fire

# Optional: RFQ all Tenor curators/funds
TENOR_BEARER=... python3 king-pod/script/FireTenorArmitageRfq.py --fire --broadcast-all

# 4) Watch matching offers
TENOR_BEARER=... python3 king-pod/script/WatchTenorRfq.py --inquiry-id <ID> --poll
```

**UI path (same packet):** OTC → Borrow → Request Quote → 700k USDC / ELE → counterparty **Armitage** → Send → accept best onchain offer → USDC to hot → route Landing / credit.

Mutation requires Tenor wallet session (`Unauthorized` without `TENOR_BEARER` / `TENOR_COOKIE`). Request itself is non-binding until an offer is accepted onchain.

## After fill

1. USDC on hot from Tenor/Morpho settle.  
2. Route to Landing, or `credit.supply` + `completer.complete` / `autoDraw.poke` on bound stack.  
3. Optional Morpho refinance slice if desk structured as refinance facility.

## Institutional backups (parallel, same ask)

| Desk | Contact | Ask |
|--|--|--|
| Wintermute OTC | https://www.wintermute.com/contact | $700k USDC facility vs ELE Morpho book |
| Wildcat | https://wildcat.finance | Institutional credit line |
| DWF | `hello@dwf-labs.com` · https://rfq.dwf-labs.com/ | Working-capital $700k |
| Galaxy GOFR | https://www.galaxy.com/global-markets/lending/galaxy-onchain-financing-rate | Structured ≥$700k–$1M |

### Backup paste

```
Subject: King Errick — $700k USDC facility vs ELE Morpho fortress (Base)

Borrower/hot: 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
Landing:      0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357
ELE:          0x50639C42E2FFDEC4F68FB468968a55b3Af944583
Morpho ELE77: 0xa4ec5271…da53fc — coll ~21.5M ELE + matched engine
ZK proven:    Elepan gate + Bound reserves gate (hot, $700k)
Primary RFQ:  Tenor OTC → Armitage (Wintermute) app.tenor.finance/otc
Ask:          $700,000 USDC to hot/Landing (facility or refinance)
Contact:      efthompson008@gmail.com
```

## Law

No hope-theater. No “no collateral.” Code RFQ is the key; backups ride the same packet. Dig until an offer prices.
