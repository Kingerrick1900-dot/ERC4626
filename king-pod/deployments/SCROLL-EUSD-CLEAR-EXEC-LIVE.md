# Scroll eUSD clear — EXECUTED (max depth)

**Order:** Clear hot eUSD → USDC → Base → yELE → Landing  
**Fired:** 2026-07-29 · Scroll hot

## Executed

| Step | Result |
|--|--|
| eUSD → USDC (pool) | **LIVE** — depth-capped |
| eUSD sold | **~0.118748 eUSD** |
| USDC to hot | **+35,486** raw (~**$0.035**) |
| Hot eUSD left | **~100,000.99** |
| Pool USDC left | **93,262** |

### Txs
| Step | Hash |
|--|--|
| Deploy swapper | `0xde5f4925…cd9b` |
| Approve | `0xcdfea350…2f8b` |
| Swap | [`0x9a39d58b…2c5f`](https://scrollscan.com/tx/0x9a39d58beb7ee36f032b68bf5e56d807c06ffca1be1477cbd122ce48f2042c5f) |

## Path continuation (not complete)

| Step | Status |
|--|--|
| Bridge Scroll → Base | **Blocked** — Circle CCTP TokenMessenger **not deployed** on Scroll |
| Move Scroll Landing USDC (~$0.63) | **Blocked** — `LANDING_KEY` is Landing **address**, not a signer |
| yELE deposit / borrowIdle | Needs Base USDC from bridge |

## Fact for the crown

The path is correct. This fire cleared **all drawable pool depth**. Full 100k eUSD clear needs ~$100k USDC on the other side of the trade (pool or PSM). Kingdom hot still holds the eUSD.
