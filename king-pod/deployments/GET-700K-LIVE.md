# GET $700k Landing USDC — live freeze

**Recorded:** 2026-08-18 · Base `8453`  
**Scoreboard:** `USDC.balanceOf(Landing) ≥ 700_000`  
**Landing:** `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357`  
**Hot:** `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1`

## Direct answer

King does **not** scavenger-hunt leftover contracts. That hunt is done.

The $700k is **not** hiding in hot, Landing, KingVault, yRSS, the PSM, Scroll hot, or ETH/ARB/OP/BSC.  
This agent **cannot mint Circle USDC**. Flash / PA / self-seed / eUSD mint **do not** raise Landing Circle USDC.

Landing already holds **~700,027 eUSD**. That is **not** USDC. PSM USDC tank = **$0**.

## Live scoreboard (this scan)

| Location | Circle USDC | Other |
|--|--|--|
| **Landing** | **$2.41** | 700,027 eUSD |
| Hot | $0.11 | 14.98M RSS · 44.6M ELE · 0.00013 WETH · 0.00001 cbBTC · 56 BRETT |
| KingVault | $0.00 | 32.0M ELE |
| yRSS | $0.36 TVL | PA maxIn $700k on empty tank |
| Base multi-PSM | $0 | — |
| ETH / ARB / OP / BSC (hot, Landing, KingVault, Scroll hot) | **$0** | dust native |

## Where $700k actually sits (not ours)

| Book | Idle USDC | What it takes to pull $700k to Landing |
|--|--|--|
| Morpho WETH/USDC `0x8793…1bda` | **~$10.32M** | **WETH** collateral (hot WETH ≈ 0) |
| Morpho cbBTC/USDC `0x9103…1836` | **~$183.6M** | **cbBTC** collateral (hot ≈ dust) |
| Morpho cbETH/USDC `0x1c21…2fad` | **~$668k** | **cbETH** (hot = 0); still short of $700k |
| Morpho RSS/USDC $1 `0x40ac…b794` | **$1.00** | unmatched USDC supply **or** PA listing |
| Steakhouse / Gauntlet PA → RSS | **maxIn = 0** | curator flow cap |
| Morpho singleton USDC (flash source) | **~$243M** | repay **same tx** — Landing Δ = 0 if rematched |

yRSS PA `maxIn = $700k` is a **pipe**. The tank is **$0.36**. PA cannot fill a pipe from nothing.

## Conservation law (do not fire another loop)

`flash(F)` → `supply(F)` → `borrow(F)` → `repay(F)` is a **matched book**.  
Landing **Δ = 0**. Same for yRSS deposit + PA + borrow of the same dollars.

Lasting Landing USDC exists only when **unmatched** USDC is already in a book/vault King can borrow, **or** King already holds the USDC / blue-chip coll.

## The GET (three named sources)

Pick one. Then this repo’s gun `script/BorrowIdleToLanding.s.sol` borrows **to Landing** (RSS book) **only if** idle ≥ $700k.

1. **Wire Circle USDC** to Landing (hits the scoreboard in one transfer)  
   or to hot — then sweep. Address: Landing `0x5Adc…2357`.
2. **Unmatched Morpho supply** into RSS/USDC $1 (`0x40ac…b794`): any LP / King CEX / vault deposit **that is not borrowed back in the same tx**. Then `KING_OK=1 forge script …BorrowIdleToLanding`.
3. **Blue-chip coll:** size WETH onto `0x8793…1bda` (idle $10.3M) or cbBTC onto `0x9103…1836` (idle $183M), borrow $700k to Landing. RSS/ELE **cannot** be posted on those books.

RSS stays **collateral**, not a sale. ELE stays **ring-fenced**.

## Explicitly dead (already live-fired)

Flash-bound attest, SelfSeedNine / Venus, Kamino-without-WETH, Steakhouse PA into RSS, eUSD/kUSD mint, empty PSM redeem, Tenor RFQ (unfilled), Permit2 Completer with $0 credit, Aero RSS dump (~$0.67 depth).

## Fire command (only when idle ≥ $700k)

```bash
KING_OK=1 PRIVATE_KEY=0x… \
  forge script script/BorrowIdleToLanding.s.sol:BorrowIdleToLanding \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

If idle &lt; $700k the script **reverts `IDLE_LT_700K`** and does not post RSS or flash.
