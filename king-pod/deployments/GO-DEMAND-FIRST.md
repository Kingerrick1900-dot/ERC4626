# GO — Demand-first fire sheet

**Status:** Armed. Waiting on hot `PRIVATE_KEY` (one-time paste).  
**Morpho $200M:** leave 250k RSS coll alone.

## Live green

| Gate | State |
|--|--|
| Free RSS | ~14.7M |
| 100M mint coll | ~129,871 RSS — **FITS** |
| Morpho signal | 250k coll intact |
| ETH gas | present |
| Fork | Trove 100M **PASS** |

## Fire order (King key)

```bash
cd king-pod
export PRIVATE_KEY=0x…   # hot — one-time
export BASE_RPC_URL=https://mainnet.base.org

# 1) Peapods scream (creates LP in-tx — PoD 100% util)
KING_GO=1 FIRE_PEAPODS=1 ASK_RSS=834 \
  forge script script/FirePeapodsRss1200.s.sol:FirePeapodsRss1200 \
  --rpc-url $BASE_RPC_URL --broadcast --slow -vvv

# 2) Vault V2 exit = gas only
KING_OK=1 forge script script/SetVaultV2ZeroPenalty.s.sol:SetVaultV2ZeroPenalty \
  --rpc-url $BASE_RPC_URL --broadcast -vvv

# 3) Mint 100M eUSD → Landing (Morpho untouched)
KING_OK=1 FIRE_TROVE=1 \
  forge script script/FireRssTroveMint.s.sol:FireRssTroveMint \
  --rpc-url $BASE_RPC_URL --broadcast --slow -vvv
```

Merkl fixed campaign: submit `deployments/merkl-rss-1200-fixed.json` in Merkl UI after scream (follow-up amp).

## Agent

Paste hot key once → agent broadcasts 1→2→3 → clears key.
