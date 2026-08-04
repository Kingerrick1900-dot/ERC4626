# Option C — Tenor RFQ $500k vs TRUE RSS

**Status:** LIVE  
**King order:** Try C $500k (2026-08-04)  
**Elepan:** NEVER touched (denylist)

## Live inquiries

| Target | Inquiry ID | Status |
|--|--|--|
| Armitage by Wintermute | `7e35d157-3dfe-40bc-81e5-e0841037976d` | active |
| Broadcast-all desks | `caaa6250-04c3-4b9a-98e1-64531f67be97` | active |

## Packet

| Field | Value |
|--|--|
| Ask | **$500,000 USDC** (`500000000000`) |
| Collateral | **TRUE RSS** `0x7a305D07B537359cf468eAea9bb176E5308bC337` (18dp) |
| Oracle | `0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e` ($1 burned-owner) |
| LLTV | 77% |
| Term | 7–30 days |
| Hot | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| Landing (post-fill) | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| Elepan denylist | `0x50639C42E2FFDEC4F68FB468968a55b3Af944583` |

## Fire / watch

```bash
set -a; source /tmp/cursor/tenor_bearer.env; set +a

# Armitage-only
python3 king-pod/script/FireTenorRssRfq500k.py --fire

# All Tenor curators/funds
python3 king-pod/script/FireTenorRssRfq500k.py --fire --broadcast-all

# Watch offers
python3 king-pod/script/WatchTenorRfq.py --inquiry-id 7e35d157-3dfe-40bc-81e5-e0841037976d --poll
```

## After a desk prices

1. Accept onchain lend offer on Tenor (hot signs).  
2. USDC → hot → **route Landing immediately**.  
3. **Do not** deposit that sleeve into yRSS / RSS Morpho market.  
4. Elepan stays free.

## Morpho idle path (parallel)

If desk supplies USDC into RSS Morpho market instead of Tenor Fixed:

```bash
# dry
ASK_USDC=500000000000 ADD_BORROW=1 \
  forge script king-pod/script/FireRssOptionCAtomicSeed.s.sol:FireRssOptionCAtomicSeed \
  --rpc-url $BASE_RPC -vv

# live (King only)
FIRE=1 ASK_USDC=500000000000 ADD_BORROW=1 COLL_RSS=800000000000000000000000 \
  forge script ... --broadcast --slow
```

Gate: `idle >= $500k`. Today idle ≈ $1 — Tenor RFQ is the active door.
