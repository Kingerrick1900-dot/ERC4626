# LAW — King signs once · HOT fires under ZK

**Problem:** 2-of-3 Safe on every Morpho move is too slow for empire ops.  
**Fix:** Safe authorizes HOT on Morpho **once**. HOT then rewrites / supplies via `CrownZkMorphoRail` (on-chain ZK). King is not in the loop every fire.

---

## One King action

1. Open Safe (browser + MetaMask):  
   https://app.safe.global/home?safe=base:0x23590feb2a668817a426d46a0447ed3ea8e3eac0
2. Import `safe-authorize-hot-once.json` in Transaction Builder  
3. 2-of-3 sign · execute  
4. Say **check again**

That tx: `Morpho.setAuthorization(HOT, true)`.

## After that (agent / HOT)

```bash
FIRE_ZK_REWRITE_SAFE_VIA_HOT=1 ZK_SHIELD=1 \
  forge script script/FireZkRewriteSafeViaHot.s.sol:FireZkRewriteSafeViaHot \
  --rpc-url "$BASE_RPC" --broadcast --with-gas-price 5000000
```

Withdraws Safe Morpho shares → `zkSupply` on rail `0xa787…` → Safe.  
Requires `isProven(HOT)` · `isProven(Safe)` · `bordersSecure`.

## Law

| Who | Signs |
|--|--|
| King / Safe | Ownership, authorize, rescue, change law — **rare** |
| HOT | Daily fires under ZK — **no Safe batch** |

```
ONE_SIG=setAuthorization(HOT)
THEN=HOT_ZK_FIRES
NO_MORE_SAFE_EVERY_TX
```
