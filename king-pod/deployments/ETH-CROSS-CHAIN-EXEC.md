# ETH Cross-Chain Rail — BUILT

**Majesty:** Wintermute printed a **$200M** SOL principal block. Kraken×Maple warehouse floor is **$500k**. Circle CCTP clears **$20B+/month** Base→Ethereum 1:1. This rail is that machine sized to **$700k**.

## Live contract (FIRED)

| | |
|--|--|
| **CrownOtcEthRail** | [`0x683886A3911323e92A6C764c3331CAC168D0029E`](https://basescan.org/address/0x683886A3911323e92A6C764c3331CAC168D0029E) |
| RSS stocked | **700,000** |
| Min fill | **$500,000** USDC |
| Target | **$700,000** USDC |
| ETH mint to | Landing `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| CCTP domain | **0** (Ethereum) |
| TokenMessenger (Base) | `0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d` |
| RFQ sheet | [`OTC-ETH-RFQ.md`](./OTC-ETH-RFQ.md) |

## Desk call (MODE_ETH = 2)

```text
approve USDC → rail for amount
fill(usdcAmt, usdcAmt * 1e12, 0, 2)
```

| Size | usdcAmt | rssOut |
|------|---------|--------|
| $500k | `500000000000` | `500000000000000000000000` |
| $700k | `700000000000` | `700000000000000000000000` |

**Effect:** USDC burned on Base → minted on **Ethereum** to Landing. Desk receives RSS same tx. No AMM. No depth proof.

## Deploy / arm

```bash
KING_OK=1 FIRE_OTC_ETH=1 STOCK_RSS=700000000000000000000000 \
  forge script script/FireOtcEthRail.s.sol:FireOtcEthRail \
  --rpc-url $BASE_RPC --broadcast --chain 8453
```

Optional kUSD inventory from Advance: `MOVE_ADV=1`.

## Already wired

| Tool | Role |
|------|------|
| `FireCctpBridgeUsdc.s.sol` | Hot USDC → ETH Landing (when hot holds size) |
| `CrownZkAdvance` | ZK door still live for Base settles |
| ZK `isProven(hot)` | **true** — attach to RFQ |

## RFQ one-liner (send to desk)

> Kingdom Base RFQ: buy **700,000 RSS** for **700,000 USDC**. Settle via `CrownOtcEthRail.fill(..., 2)` — USDC CCTP-mints to Ethereum `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357`. ZK reserves proven on-chain. Min **$500k**.
