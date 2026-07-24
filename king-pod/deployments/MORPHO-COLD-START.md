# Morpho Cold-Start — Emit Your Token (GROWTH LOOP — not a USDC access key)

**Class:** Growth loop / lender magnet. Same honesty rule as flash-seed: **does not unlock the credit lines King already posted.**  
For live credit vs access, see `INVENTORY-LIVE.md`.

**Doctrine correction:** Every Morpho market / vault starts with no external idle.  
That is the **default**, not a Kingdom special failure. Morpho’s own docs name the bootstrap lever:

> Vault-level incentives — **“Bootstrap a new vault to attract initial liquidity.”**  
> Source: [Morpho Reward Campaigns](https://docs.morpho.org/developers/rewards/concepts/reward-campaigns/)

> Incentives come from **“Market creators bootstrapping liquidity”** and **“Token issuers promoting asset usage.”**  
> Source: [Rewards on Morpho](https://docs.morpho.org/learn/concepts/rewards)

> **Focus incentives on lenders first** — attracting supply is the main launch challenge.  
> Commit **90 days**, send incentives **upfront**, schedule 1/9 → 3/9 → 5/9.  
> Source: [Morpho forum — standard incentives](https://forum.morpho.org/t/standard-method-for-distributing-incentives-on-morpho-blue-markets/412)

> **Blacklist treasury** so bootstrap liquidity does not self-earn the budget.  
> Source: same Morpho reward-campaigns docs (Blacklisting)

**No broadcast without King `KING_GO=1` + `FIRE_EMIT=1`.**

---

## What was wrong in prior framing

| Bad framing | Morpho reality |
|--|--|
| “Kingdom lacks external funds — stuck” | Every new vault / Blue market starts that way |
| “Need USDC first, then emit” | Emit **is** how you get external USDC |
| “Merkl whitelist blocked = no path” | Merkl is discovery amp; own distributor is the Morpho URD-era pattern |
| Matched flash seed = paycheck | Seed is the magnet book; **emissions** pull real lenders into idle |

Matched flash seed (vault ~$14M @ ~100% util) already did Morpho step 0: create borrow demand / rate magnet.  
Step 1 in Morpho’s playbook is **token incentives for lenders** — Kingdom’s free Elepan bag.

---

## Live Kingdom map (cold-start ready)

| Piece | State |
|--|--|
| Free Elepan (hot) | **~34.58M** — the incentive budget |
| yELEPAN-USDC | `0x61bfD6F7df1f72427F472144d043c25d742D145E` · ~$14M TVL |
| Share holder today | Landing ≈ **100%** (blacklist this — Morpho pattern) |
| ELE/USDC Morpho idle | **~$0** (100% util) — needs **external** USDC supply |
| Hot Morpho coll headroom | ~$16.9M more borrow room **after** idle appears |
| Merkl amp | Blocked until Elepan reward-token whitelist (optional parallel) |

---

## Cold-start sequence (Morpho-shaped)

```
1. Emit Elepan → EXTERNAL yELEPAN depositors   FIRE_EMIT=1
2. External USDC deposits into yELEPAN         (lenders chase APR)
3. Vault supplies USDC → ELE/USDC market       (idle appears)
4. King borrows idle → Landing                 FIRE_BORROW=1
```

That is the documented Morpho lender-first loop. Not a guess from failed scripts.

### Armed rail — own stream (no Merkl)

| Item | Value |
|--|--|
| Contract | `CrownYelepanStream` |
| Fire | `script/FireOwnElepanEmit.s.sol` |
| Reward | Elepan `0x50639C42…4583` |
| Target shares | yELEPAN depositors |
| Default budget | **4,000,000 Elepan / 28 days** |
| Blacklist | Landing + hot (treasury does not earn) |
| Behavior if eligibleSupply=0 | Rate **pauses** — budget waits for first external LP |

```bash
cd king-pod
KING_GO=1 FIRE_EMIT=1 \
  forge script script/FireOwnElepanEmit.s.sol:FireOwnElepanEmit \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

Overrides:
```bash
BUDGET_ELEPAN=900000000000000 DURATION_SEC=7776000   # 9M / 90d (Morpho forum lens)
STREAM=0x...                                         # top-up existing stream
```

### Morpho 90-day schedule (optional King sizing)

Using free ~34.58M as ceiling, example **9M Elepan / 90d** (forum 1/9·3/9·5/9):

| Window | Elepan | Notes |
|--|--|--|
| Days 0–30 | 1M | Thin start; rate magnet + first APR quote |
| Days 30–60 | 3M | Scale as external TVL shows |
| Days 60–90 | 5M | Hold depth while borrow → Landing runs |

Fire as three `notifyRewardAmount` top-ups, or one 90d stream — King chooses.

### Parallel amp — Merkl (when whitelist clears)

Same budget class, Morpho UI discovery. Does **not** gate `FIRE_EMIT`.  
Packet lives on the Merkl campaign branch when King wants that amp.

---

## After first external idle

```bash
KING_GO=1 FIRE_BORROW=1 BORROW_USDC=<raw6> \
  forge script script/FireElepanBorrowUsdc.s.sol:FireElepanBorrowUsdc \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

Idle floor defaults protect against dust hopes. Real paycheck = external supply − existing borrow.

---

## One-line

> Morpho cold-starts by **emitting the project token to vault lenders**; Kingdom’s free **~34.58M Elepan** is that budget — `FIRE_EMIT` is the Morpho path, not a consolation prize after “finding external money.”
