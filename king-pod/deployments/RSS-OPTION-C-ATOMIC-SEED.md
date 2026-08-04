# RSS Option C — Atomic Seed → Landing

**Status:** ARMED (await Step 1 lender live)  
**Doctrine:** Elepan stays free. RSS = decoy bait. No desk-wait hope — fire only when lender USDC is **onchain-live**.

## King plan

| Step | Action | Gate |
|--|--|--|
| **1** | Confirm lender commitment (Armitage / Wintermute / DWF) — **Option C** | RSS Morpho market idle USDC ≥ ask **or** signed Tenor lend offer ready to accept |
| **2** | 15M true RSS authority | Holding address + approve Morpho |
| **3** | Atomic fire | Post RSS → borrow USDC → **Landing** |

## Live facts (2026-08-03)

| Item | Value |
|--|--|
| True RSS | `0x7a305D07B537359cf468eAea9bb176E5308bC337` (18dp) |
| Hot (Step 2 address) | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` — **~15,030,000 RSS** · Morpho loan **0** |
| Elepan | `0x50639…` — **do not touch** |
| Landing | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| RSS market | `0x40ac09f3…b794` · oracle `$1` burned-owner `0x284EC3…` · LLTV 77% |
| Ask | **$600,000–$700,000** USDC |

## Step 1 — Lender commitment (Option C)

**Pass condition (either):**

1. **Morpho depth:** `idle = supplyAssets − borrowAssets` on RSS market ≥ `ASK_USDC` ($500k–$700k raw 6dp), supplied by desk; **or**
2. **Tenor offer:** live onchain lend offer vs TRUE RSS `0x7a305…` sized ≥ ask — see `TENOR-RSS-RFQ-500K.md` (inquiries already live).

**Check:**

```bash
python3 king-pod/script/CheckRssLenderCommitment.py --ask 700000
```

Fails while idle ≈ $1 and no Tenor offer — **do not fire Step 3**.

## Step 2 — RSS authority

- Holding address: **hot** (confirmed ~15.03M).
- At fire, script `approve(MORPHO, collateral)`.
- Collateral for $700k @ 77% / $1 ≈ **~909,091 RSS** (buffer to ~1.0M–1.2M RSS). Leave remainder free on hot.

## Step 3 — Atomic fire (gated)

```bash
# Dry: prints gates only
ASK_USDC=700000000000 PRIVATE_KEY=… forge script \
  king-pod/script/FireRssOptionCAtomicSeed.s.sol:FireRssOptionCAtomicSeed \
  --rpc-url $BASE_RPC -vvvv

# Live (King order only) — requires IDLE_OK
FIRE=1 ASK_USDC=700000000000 COLL_RSS=1200000000000000000000000 PRIVATE_KEY=… \
  forge script king-pod/script/FireRssOptionCAtomicSeed.s.sol:FireRssOptionCAtomicSeed \
  --rpc-url $BASE_RPC --broadcast --slow
```

**Guarantees in code:** revert if idle < ask; revert if RSS bal short; borrow `receiver = Landing`; never touches Elepan.

## Hard rules

- No Armitage RFQ-wait as primary.
- No price raise on burned RSS oracle.
- No Elepan collateral.
- No fire until Step 1 live.
