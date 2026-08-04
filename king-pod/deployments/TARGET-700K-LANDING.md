# TARGET $700k — LIVE STATUS

**Goal:** Landing `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` += **$700,000 USDC**

## Step 1 — FREE · DONE

| | |
|--|--|
| Tx | `0xd01b7b9668f3e8f1e465d0e816eb12786468df4bfbb4d21374aff26ff048afab` |
| Freer | `0xcFEaEC4eD07559963b0dc21aD46517e3bb9B823A` |
| Hot RSS after | **~10,029,600** |
| Morpho debt left | dust ~**$300** |
| Morpho coll left | ~**400 RSS** |
| yRSS TVL after | ~**$299** |

Circular ~$700k loop unwound. Ammo on hot.

## Step 2 — BORROW $700k → Landing · ARMED / NOT FILLED YET

Bundler3 dry @ ask **$700k**:

- `rssOk` = 1 (ammo enough)
- `idleOk` = 0
- `ltvOk` = 0 (needs idle to borrow)
- Foreign PA maxIn (Gauntlet/Steakhouse) = **0**
- FIRE list empty

```bash
# Keep hunting + auto-fire first green rail at $700k
python3 king-pod/script/ScanAllRails.py --poll --interval 60 --auto-fire --ask 700000

# Direct when idle/PA greens
ASK_USDC=700000000000 COLL_RSS=2000000000000000000000000 FIRE=1 \
  forge script script/FireBundler3AtomicPack.s.sol:FireBundler3AtomicPack \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

## Scoreboard

| Metric | Now |
|--|--|
| Landing USDC | **~$3.40** |
| Target | **$700,000** |
| Hot RSS (ammo) | **~10.03M** · ready |

No recycle of freed RSS into yRSS/self-seed. Next dollar move = Morpho borrow $700k → Landing when rail greens.
