# PSM seed — WIRE_USDC + FREE_KXAU — LIVE

**Order:** Authorize deposit of WIRE_USDC and FREE_KXAU into gold PSM `0x0644…75dA`.  
**Fired:** 2026-07-29 · Scroll

## Seeded

| Asset | Amount | USD notional |
|--|--|--|
| USDC | **660,548** raw (~**$0.6605**) | from Landing wire + hot dust |
| kXAU | **0.93000001** | ~**$9.30** @ $10 oracle |

## PSM reserves after

| Call | Value |
|--|--|
| `usdcReserve()` | **660548** |
| `goldReserveUsd6()` | **9300000** (~$9.30) |
| Hot USDC / kXAU | **0 / 0** (fully deposited) |
| Landing USDC | **0** |

## Txs

| Step | Hash |
|--|--|
| Landing → Hot USDC | [`0x382e4950…e903`](https://scrollscan.com/tx/0x382e49506a1c6b2a8ed88a1deb3065b0d793afedbe1b65f7bde135eee6d6e903) |
| `seedUsdc` | [`0x283864ba…bcc9`](https://scrollscan.com/tx/0x283864ba3be321480a57dc480921647ebd8cd3d7dcf596333134ff0a923abcc9) |
| `seedKxau` | [`0xd38f4518…471e`](https://scrollscan.com/tx/0xd38f451888cd26c40c0c73cba6373944adaafeeccf2e46cf87e19d251a35471e) |

## Floor status

Redeem path is **live** at this reserve size:
- `redeemUsdc` capacity ≈ **$0.66**
- `redeemKxau` capacity ≈ **$9.30**

Keeper may run against that floor. Larger capitalize tranche still needed for meaningful arb.

CDP kXAU (100,001) untouched — only free hot kXAU seeded.

Status: `PSM_SEED_WIRE_KXAU_OK`
