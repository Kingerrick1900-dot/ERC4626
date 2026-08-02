# Landing $500k hard USDC — GO packet (existing tools only)

**Status:** ARMED · no new builds · live fire only when idle ≥ ask  
**Goal:** Base Landing `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` ≥ **$500,000 USDC**  
**Ask raw:** `500000000000` (6dp)

## Live facts (Base)

| Field | Value |
|--|--|
| Hot coll on ELE77 | ~**2,000,003 ELE** |
| Hot borrow | ~**$700,000** |
| Headroom @ 77% LLTV | ~**$840,000** (≥ $500k) |
| ELE77 idle now | ~**$0** (matched) |
| Morpho API | util ~**100%** · supply/borrow APY ~**13.4%** · `reallocatableLiquidityAssets=0` · `publicAllocatorSharedLiquidity=[]` |
| yELE | `0x61bfD6F7df1f72427F472144d043c25d742D145E` |
| Extractor | `0x5d99EEf1954053EDc4D73ba1429E51DaC539bf58` |
| Morpho auth | extractor authorized on hot (DiskFill live) |
| Fire gate | **idle ≥ $500k** — do not broadcast before that |

**Battle-tested mechanic:** external USDC supply → Morpho idle → `borrowIdle` → Landing. Never flash-mirror.

---

## Path A — External USDC → yELE → borrowIdle (PRIMARY)

1. **Depositor** (not matched self-seed) sends ≥ **$500k USDC** into **yELE** (`deposit`).
2. yELE queue routes into **ELE77** (or curator realloc WETH→ELE if deposited on WETH slot).
3. ELE77 idle ≥ $500k.
4. King fires existing extractor:

```bash
# Read-only gate check first
cast call 0x5d99EEf1954053EDc4D73ba1429E51DaC539bf58 \
  "borrowIdle(uint256)" 500000000000 \
  --from 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1 \
  --rpc-url $BASE_RPC

# LIVE (King GO only) — hot key
cast send 0x5d99EEf1954053EDc4D73ba1429E51DaC539bf58 \
  "borrowIdle(uint256)" 500000000000 \
  --private-key "$PRIVATE_KEY" --rpc-url $BASE_RPC
```

5. **Scoreboard:** `USDC.balanceOf(Landing) ≥ 500_000e6`.

**Kill if:** depositor is hot recycling Morpho-borrowed USDC (remainder-0 mirror).

---

## Path B — Foreign curator maxIn → PA → borrow (WHALE DOOR)

See `CURATOR-PACKET-ELE77.md`.

When Gauntlet / Steakhouse (or any vault) sets **ELE77 maxIn ≥ $500k** and has liquid supply elsewhere:

1. PA `reallocateTo` into ELE77 (existing `CrownLeverageExtractor.reallocateAndBorrow` / Morpho PA).
2. `borrowIdle(500000000000)` → Landing.
3. Same scoreboard.

**Block today:** foreign vaults have **ELE77 enabled=false / maxIn=0**.

---

## Pre-flight (every fire)

```text
idle(ELE77)     >= 500_000e6
headroom(hot)   >= 500_000e6
Landing Δ       >= 500_000e6 - 1e6
extractor auth  == true (live: true)
NO new contracts
NO DiskFill that requires hot to fund the ask from nowhere
```

**Note:** `borrowIdle` succeeds on-chain even when idle=0 (borrows nothing). Always check idle before broadcast.

## Fork / prove

`test/DiskFillWarped.t.sol::test_landing_500k_borrowIdle_external_deposit` — whale deposits $500k → live extractor `borrowIdle`. Local Foundry on latest Base may hit Isthmus fee-scalar panic; pin pre-Isthmus block or re-run when Foundry patched. Live gate remains: idle ≥ ask.

## Kill rules

1. No self-seed / flash-supply-borrow-repay as payroll.  
2. No new builds.  
3. No live fire while idle < ask.  
4. Morpho debt rises by ~$500k — ops USDC on Landing is the point; repayment plan is separate King order.
