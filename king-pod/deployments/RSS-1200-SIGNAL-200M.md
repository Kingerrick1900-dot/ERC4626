# RSS/$1200 $200M seed — LIVE

**FIRED on Base.** Own seed. Matched book. No USDC buffer. Gas = ETH only.

## Live result

| Field | Value |
|--|--|
| Status | **ONCHAIN SUCCESS** |
| Signal chassis | `0x8dc77cD21cC8d872CdE2c8A75b6dEfAE73De3667` |
| Market | `0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88` |
| Supply / Borrow | **~$200,000,000 / $200,000,000** |
| Hot RSS coll | **250,000** |
| HF | **1.50** |
| Hot RSS free | **~14.73M** (≥1M headroom) |
| Morpho auth | **left ON** (unwind armed) |

## Txs

| Step | Hash |
|--|--|
| Deploy `CrownRss1200Signal` | [`0xbb7d0b81…571338`](https://basescan.org/tx/0xbb7d0b8145262a562f2e0297f175691d60ec211155a316c5d46bd7eea0571338) |
| `setAuthorization` | [`0xcb345f8f…cab87e`](https://basescan.org/tx/0xcb345f8fb69f37e084121c36d75860f8f8bf26dba657923f460b1ece84cab87e) |
| Approve RSS | [`0xdfd89d39…32ffe35`](https://basescan.org/tx/0xdfd89d3922ae956bd77a90eec116928affcfce7763f89ea6fde8cda9032ffe35) |
| Approve USDC dust | [`0x5bf00ece…ae9946`](https://basescan.org/tx/0x5bf00ece64999c2865582babb4a13da6ca25b6840c1c07e8e767401e21ae9946) |
| **`seed($200M)`** | [`0x4e062ab0…52eb3c`](https://basescan.org/tx/0x4e062ab044d64912baf6ce14f7f712f70412e2472e89119a5a8f2d150152eb3c) |

## Unwind (anytime)

```bash
KING_OK=1 FIRE_UNWIND=1 SIGNAL=0x8dc77cD21cC8d872CdE2c8A75b6dEfAE73De3667 \
  forge script script/UnwindRss1200Signal.s.sol:UnwindRss1200Signal \
  --rpc-url https://mainnet.base.org --broadcast --slow -vvv
```

`unwind` = `selfDel` = `selfLiq`. RSS returns to hot. Book → zero.
