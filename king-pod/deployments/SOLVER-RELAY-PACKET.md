# ERC-7683 Solver Relay Packet — Elepan / King Errick

**Status:** LIVE · public fill enabled  
**Register this packet with Across · UniswapX · LI.FI · independent solvers**

---

## Settlement contracts

| Chain | Role | Address |
|--|--|--|
| **Scroll** | `ISettlementContract` / origin settler | **`0x44F92261C9Bf9d6B1798b8756B9135650C615A83`** |
| Scroll | ERC-7540 async redeem vault | `0x846E34c0c83FC3DA7Df953A628CC2FD4E66C434D` |
| Scroll | Gold Parity PSM (underlying) | `0x064489A287448674AA1dC6fb740d2F518CBA75dA` |
| Base | Cross-chain settlement peer | `0xbedA9C5da5582B6FD293a9a77b754FA2CB0B8982` |
| Scroll | Cross-chain settlement peer | `0x102c7249fd2C2d8Fe0ec4aea65c4880047E9f8B0` |

Chain IDs: Scroll `534352` · Base `8453`

---

## Order type

```
ORDER_TYPE_PSM_REDEEM =
  keccak256("CrownPsmRedeem(address user,uint256 eusdAmt,address baseRecipient,uint256 minUsdc)")
```

`orderData` ABI: `(address user, uint256 eusdAmt, address baseRecipient, uint256 minUsdc)`

### Solver flow
1. **Scan** `open` / pending vault requests on Scroll settler + vault  
2. **Price** via Base v4 hook `getReferencePrice` + Chainlink-style PoR  
3. **`fill(orderId, originData, fillerData)`** — front USDC to `baseRecipient` on fill surface  
4. **`settle(orderId)`** on Scroll — fulfill 7540 → claim PSM USDC → solver reclaim  

`publicFillEnabled = true` — no whitelist required.

---

## Price + PoR (solver gates)

| Feed | Address | Chain | Signal |
|--|--|--|--|
| Uniswap v4 eUSD hook | `0xD439DC646C807BFa704EE726fD9fCcfFde6605a7` | Base | TWAP reference WAD |
| ELE77 PoR (AggregatorV3) | `0x3640f1CC913B772EA4D9BDF96a67196590058379` | Base | Morpho supply USDC 6dp |
| Gold CDP PoR (AggregatorV3) | `0xFE0874449f3eb50C1BBe62D8BA38db346cACBf59` | Scroll | Collateral USD 6dp |

```bash
# PoR
cast call 0x3640f1CC913B772EA4D9BDF96a67196590058379 "latestRoundData()" --rpc-url $BASE_RPC
cast call 0xFE0874449f3eb50C1BBe62D8BA38db346cACBf59 "latestRoundData()" --rpc-url $SCROLL_RPC

# Settlement
cast call 0x44F92261C9Bf9d6B1798b8756B9135650C615A83 "publicFillEnabled()(bool)" --rpc-url $SCROLL_RPC
```

---

## Tokens

| Asset | Base | Scroll |
|--|--|--|
| eUSD | `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a` | `0x41Ba09c14DaeF5D0E95E6A78Ca94d2CbBb001B0B` |
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` | `0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4` |

Peg law: 1 eUSD = $1.00 via PSM redeem depth + pool mark.

---

## Contact / ops

- Hot Base: `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1`  
- Hot Scroll: `0xca76AE9e29a5F01465D890dc30109cD58B78F864`  
- Landing: `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357`  

**Broadcast surface:** this packet + on-chain settler. No private keeper required.
