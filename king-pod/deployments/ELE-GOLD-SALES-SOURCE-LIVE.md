# ELE + GOLD sale-source pools — LIVE

Base dead pools were lit with real inventory and real USDC so ELE and kXAU have same-chain sale surfaces today.

## Live pools

| Pair | Fee | Pool | Seed |
|--|--|--|--|
| ELE / USDC | 0.3% | `0x4615a3E473944C12bDF4e1E3d1ea5e5968397410` | `1 ELE` + `$1 USDC` |
| GOLD / USDC | 0.3% | `0x47EBd710De9c0396AC44927A7CC3345F13b321A7` | `0.1 GOLD` + `$1 USDC` |

## Position NFTs

| Pair | Token ID | Owner |
|--|--|--|
| ELE / USDC | `5669978` | hot `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| GOLD / USDC | `5669999` | hot `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |

## Tx hashes

| Action | Tx |
|--|--|
| Approve ELE to NPM | `0x17c1925f8847668026576c64128829039ad28a6bd5e584c86cf414e726fed810` |
| Approve GOLD to NPM | `0x02570b0a79c00056a6da75249317ee1661ecf32e73416e4a7a9b1d40e63d6287` |
| Approve USDC to NPM | `0xf2f9378c35cef7297bf9e9f3e6f85e9d031fd74ac82c5c9cc6148c8dd66b3e9d` |
| Mint ELE / USDC position | `0x59970176298573fdff2d63c2a68a09ef790d92376b30f8d1db578df5ad00252c` |
| Create + initialize GOLD / USDC pool | `0xb60f5c368269f898452e27c602c4ca675dc2faa771b17e5867ff2cc179c1d619` |
| Mint GOLD / USDC position | `0xac639f5bc7da875f1db5ab76bca65162472ea12c887e95e89493b9c8aaa7ef4b` |

## Notes

- ELE / USDC already existed but was dust-dead (`1 / 1` balances, zero liquidity).
- GOLD / USDC did not exist and had to be created live.
- `createAndInitializePoolIfNecessary` needed a large gas ceiling on Base (~4.6M used) even though the fork path passed at lower envelope.
- Hot residual after seeding stayed above `$1 USDC` and with Base ETH intact for ops.
