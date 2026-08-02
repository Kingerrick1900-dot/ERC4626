# Gold PSM Bridge — LIVE

**Order:** Build the PSM bridge. Link Base to Scroll. Let the code catch up.  
**Prior:** PR #69 capacity · PR #72 unit liquidity · **this module = gold parity rail**

```
BASE ENGINE                              SCROLL ANCHOR
ELE77 + ELE/eUSD pool                    kXAU CDP + Gold Parity PSM
         \                                    /
          \___ Base eUSD Link _______________/
               Scroll eUSD Link
            1 eUSD = $1.00 gold parity
```

## LIVE addresses

| Piece | Chain | Address |
|--|--|--|
| **Gold Parity PSM** | Scroll | `0x064489A287448674AA1dC6fb740d2F518CBA75dA` |
| **Scroll eUSD Link** | Scroll | `0xb7b1EfC8621764BeF097a34cD22B75Ac0706A7b6` |
| **Base eUSD Link** | Base | `0x860E508DD874a8046329b314fD5311567DB8516D` |
| Oracle ($10 kXAU) | Scroll | `0xccB83516c5E9c557B9407ABF00865fe516B4a8c8` |
| Scroll eUSD | Scroll | `0x41Ba09c14DaeF5D0E95E6A78Ca94d2CbBb001B0B` |
| Base eUSD | Base | `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a` |

PSM + Scroll link are **minters** on Scroll eUSD.

## Peg law (now in code)

- `redeemUsdc(eusd)` — $1 → USDC when reserved  
- `redeemKxau(eusd)` — $1 → kXAU at $10 oracle when gold reserved in PSM  
- Thin-pool wallet marks ($0.29) are not law; redeem depth is

## Cross-chain link

1. Base: `lockForScroll(amt, scrollTo)` on Base link  
2. Scroll: king `mintFromBase(to, amt, baseLockId, baseTx)`  
3. Reverse: Scroll `burnForBase` → Base `unlock`

## Next seed (ops)

Seed PSM with USDC and/or free kXAU so public redeem can run and arb the display price.

## Txs

| Step | Hash |
|--|--|
| Deploy Gold PSM | [`0x4def7391…b893`](https://scrollscan.com/tx/0x4def7391e95050fa92a8fe58e878ce7e2a876b77491e54a84ef39679aba0b893) |
| Deploy Scroll link | [`0x16b9fd81…a478`](https://scrollscan.com/tx/0x16b9fd81e48dffd9889865c15b0f16128f51d63232a37e2570b1ea6e937ea478) |
| setMinter PSM | `0x7743cae2…a9ce` |
| setMinter link | `0xae5f29d4…c44b` |
| Deploy Base link | [`0x55aac0b9…7c37`](https://basescan.org/tx/0x55aac0b9f0ebbabb4866cc8d98051982d2e2941a7efd49c6010536d623027c37) |

Status: `GOLD_RAIL_SCROLL_OK` · `BASE_EUSD_LINK_OK`
