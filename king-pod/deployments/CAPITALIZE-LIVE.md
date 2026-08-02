# System Capitalization — LIVE

**Directive:** Feed the elephant · micro-seed · solver surface · PoR verify  
**Branch:** `cursor/fullstack-protocol-stack-efa1`

---

## 1. Micro-seed — DONE

### Base eUSD/USDC (behind v4 hook plane)
| Field | Value |
|--|--|
| Pool (Uni V3 0.05%) | `0x96D0022c7a65EE7D1819D9f48C48E4f90d91a666` |
| Position NFT | **`5703721`** |
| Liquidity | `11091466007329` |
| Hook observation | pushed on `0xD439DC646C807BFa704EE726fD9fCcfFde6605a7` |
| Maker PSM USDC (post-seed) | **~$1.46** (`1456559` raw) |

Script: `FireMicroSeedCapitalize.s.sol` · `FIRE_MICRO_BASE=1` · `MICRO_BASE_OK`

### Scroll PSM queue (ERC-7540)
| Field | Value |
|--|--|
| Vault | `0x846E34c0c83FC3DA7Df953A628CC2FD4E66C434D` |
| Queue requestId | **`1`** (1 eUSD pending redeem) |
| PSM USDC reserve | **660548** (~$0.66) |
| PSM gold reserve | **~$9.30** USD |

`FIRE_MICRO_SCROLL=1` · `MICRO_SCROLL_OK`

---

## 2. Solver registration — PACKET LIVE

See **`SOLVER-RELAY-PACKET.md`**.

Primary settler for Across / UniswapX / LI.FI:

**`0x44F92261C9Bf9d6B1798b8756B9135650C615A83`** (Scroll)

`publicFillEnabled = true`.

---

## 3. Chainlink PoR — VERIFIED LIVE

| Feed | Address | latest answer | Notes |
|--|--|--|--|
| ELE77 | `0x3640f1CC…8379` | **16516971170498** (~$16.52M USDC supply) | `bumpRound` fired |
| Gold CDP | `0xFE087444…Bf59` | **1000010000000** ($1,000,010 coll) | HF **1.55e18** · debt ~645k eUSD |

```bash
cast call 0x3640f1CC913B772EA4D9BDF96a67196590058379 \
  "latestRoundData()(uint80,int256,uint256,uint256,uint80)" --rpc-url $BASE_RPC_URL
cast call 0xFE0874449f3eb50C1BBe62D8BA38db346cACBf59 \
  "latestRoundData()(uint80,int256,uint256,uint256,uint80)" --rpc-url $SCROLL_RPC
```

---

## Next scale (same rails)

1. CCTP bridge sized USDC → Scroll `seedUsdc` on PSM `0x064489…75dA`  
2. Re-seed Base pool with balanced ticks when ≥ $500–$1k USDC available  
3. Route WETH/cbBTC into ELE77 / wet Morpho for borrow headroom  
4. Wire 0.1% toll → Scroll PSM (fee module) when arb volume appears  

Landing still holds **945003** USDC ($0.945) as ops float.
