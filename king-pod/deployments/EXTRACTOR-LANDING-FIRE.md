# CrownLeverageExtractor — Landing Fire (live)

**Status:** EXECUTED on Base · no new contracts · no new loops  
**Doctrine:** idle exists → move vault liquidity / wet coll onto borrowable books → Landing.

## Landing proof

| | |
|--|--|
| Landing | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| USDC before | **3** wei |
| USDC after | **945,003** ($0.945003) |

## Fires (Base)

| Step | Path | Amount → Landing | Tx |
|--|--|--|--|
| 1 | `CrownLeverageExtractor.reallocateAndBorrow` — PA yRSS BRETT → ELE77 → borrow | **$0.30** | [`0x2b18e5c1…752d18`](https://basescan.org/tx/0x2b18e5c1d0c14a75deb2ca8e3dcd5dab364b740b54dba6202e5ff8438e752d18) |
| 2 | Wrap ETH → post WETH coll on WETH/USDC (idle ~$8.3M) → borrow | **$0.20** | wrap [`0x1221cb5a…`](https://basescan.org/tx/0x1221cb5ab97fcd91ea7493a2214836638266a3fc3b72c398c0f3cf8d332346bd) · coll [`0xacc461c7…`](https://basescan.org/tx/0xacc461c7f226968257c7dd653ac8b0c00cf0aedceef0438169aceefda141a636) · borrow [`0xc71b2ab9…`](https://basescan.org/tx/0xc71b2ab9aedcdc7cddc9409403a707f297dbd33d2446909d8be5667bb47a0bfd) |
| 3 | Post cbBTC dust (771 sats) on cbBTC/USDC (idle ~$151M) → borrow | **$0.40** | coll [`0x1eebb808…`](https://basescan.org/tx/0x1eebb80898b58d781c5068d205b128e8ee9ac55aeec21b144dc9a91bad5306fb) · borrow [`0x09edd760…`](https://basescan.org/tx/0x09edd760c74a694147c08ae1e566d8f608a932c435a459e70a88f2fa10e550f8) |
| 4 | Extractor PA remainder yRSS BRETT → ELE77 → borrow | **$0.045** | [`0x67669a8d…`](https://basescan.org/tx/0x67669a8d213742a2dcf744ea90058a722e15fb0a498ffa09592114f3db8e3732) |
| 5 | `borrowIdle(0)` sweep (no residual idle) | **$0** | [`0x46c1e201…`](https://basescan.org/tx/0x46c1e201cc19f826a363456e877a73006f04c3695fd3ad600f8ea3f16032b9af) |
| 6 | Move **6.5M ELE** free coll off Set B (LLTV headroom) → hot | — | [`0x68903219…`](https://basescan.org/tx/0x6890321940f574b93eaea621913fbd8b4298178a55a65e4b9222a29ce0098d80) |

## What the extractor proved

Live extractor `0x5d99EEf1954053EDc4D73ba1429E51DaC539bf58`:

1. PA-pull idle USDC from a vault market (yRSS BRETT) into ELE77.
2. Borrow against already-posted ELE coll.
3. Receiver = Landing.

DeepSeek wet-book path (same session, Morpho direct — no new build):

1. Post kingdom WETH / cbBTC dust onto markets that already hold millions idle.
2. Borrow idle USDC → Landing.

## Size constraint (honest)

Kingdom wet inventory was dust (ETH wrap + 771 sats cbBTC + yRSS ~$0.35).  
Rail is proven. Scale needs **WETH / cbBTC / cbETH inventory** (or foreign PA `maxIn` into ELE77) — not another matched flash loop.

## Post-state

| Surface | Live |
|--|--|
| Landing USDC | **$0.945003** |
| Hot free ELE | ~**44.6M** (was ~38.1M; +6.5M from Set B) |
| Set B ELE coll | ~**21.5M** posted |
| Hot WETH Morpho coll | ~0.000134 WETH · debt $0.20 |
| Hot cbBTC Morpho coll | 771 sats · debt $0.40 |
| Extractor | live · authorized · allocator on yELE |

## Next scale (same tools)

When treasury holds sized WETH/cbBTC/cbETH **or** yELE holds sized USDC on WETH:

```bash
# disk fill (yELE USDC on WETH → ELE77 → Landing)
cast send 0x5d99EEf1954053EDc4D73ba1429E51DaC539bf58 \
  "curatorDiskFill(uint256)" <ASK> \
  --private-key "$PRIVATE_KEY" --rpc-url "$BASE_RPC_URL"

# or direct wet borrow once coll posted
cast send $MORPHO "borrow(...)" <ASK> 0 $HOT $LAND ...
```
