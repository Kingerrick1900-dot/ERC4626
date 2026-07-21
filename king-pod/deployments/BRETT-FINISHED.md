# BRETT rail — FINISHED (live)

**Fire:** `FireFinishBrett.s.sol` · `KING_OK=1` · `FIRE_BRETT_FINISH=1`  
**Broadcast:** `broadcast/FireFinishBrett.s.sol/8453/run-latest.json`

## What fired (one bundle)

1. **yRSS reallocate** — pulled USDC from RSS91 → **BRETT/USDC Morpho book** (lender idle)
2. **Aerodrome** — hot ETH → **~185 BRETT** on hot
3. **Morpho** — posted **all BRETT** as collateral on Kingdom BRETT market
4. **Borrow** — USDC → **Landing** (conservative 50% LTV headroom)

## Honest scale

Hot ETH was ~**0.001 ETH** — buy + borrow is **dust scale** (~**$0.30** USDC to Landing on first fire).  
**Rail is proven in use**, not cosplay. Size scales when hot sends **more ETH/USDC** for BRETT seed.

## Live refs

| | |
|--|--|
| BRETT market | `0xf6f43f1660f1f4779e92a2e21086f4ab49a3fc0cae8a17992808e6a6db488c16` |
| BRETT token | `0x532f27101965dd16442E59d40670FaF5eBB142E4` |
| Script | `script/FireFinishBrett.s.sol` |

Scoreboard: `bash script/plays-status.sh`
