# Landing emptied + frozen

**Landing (frozen):** `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357`  
**Key was exposed in chat — abandon this address. Do not reuse. Do not top up.**

| Asset | Status |
|--|--|
| USDC **$59.383375** | Moved → hot `0x6708…a7d1` · tx [`0x8723eb8d…782a4a`](https://basescan.org/tx/0x8723eb8d0205e546e645b1123c57b29b848d9ddc218c1c3b259cb5117f782a4a) |
| ELE / eUSD / yELE-K | 0 |
| ETH dust (~0.0004) | Left on Landing — sends to hot EIP-7702 fail; not worth ops risk |

## Hot after move

- USDC ≈ **$60.38** (prior ~$1 + Landing $59.38)
- Ops float is on **hot only**

## Freeze rules

1. No further Landing broadcasts.
2. Unset any `LANDING_KEY` in env / CI.
3. Treat Landing as compromised (key in chat).
4. Next dollar rails: hot USDC + ELE/USDC pool / pot unlock — not this address.
