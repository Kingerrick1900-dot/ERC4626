# STAY IDLE + USE yRSS SHARES

**Status:** CODE READY · deploy gated `KING_GO=1` · fire gated  
**Branch:** `cursor/morpho-create-idle-2m-4f7f`  
**Law:** Supply-only Morpho idle that **stays**. Never gasPark. Shares peel the instant robots see idle.

---

## Why this exists

Old helper `0xe87e…62960be8` **gasPark** = flash → yRSS.deposit → Morpho supply → king **borrows same USDC** → matched book → **$0 lasting idle** → `maxWithdraw(HOT) ≈ 2`. Shares locked. Payroll dead.

These two contracts retire that path for payroll:

| Contract | Job |
|--|--|
| `CrownStayIdlePuller` | USDC → `Morpho.supply` **direct**. No borrow. Util buffer (default 90%). Then `pullSharesToLanding` / `pokePull`. |
| `CrownYrssLiberator` | Use the **~$1M yRSS shares we already hold**. Repay wedge opens idle → `liberateToLanding` / `pokeLiberate`. |

Robots: call `pokePull` / `pokeLiberate` the instant Morpho idle > 0 and `maxWithdraw` opens. That is the “serves the king” latch.

---

## Share physics (honest)

- yRSS claim ≈ **$1.01M** on HOT. Locked while park market util ≈ 100%.
- `repayAndLiberate(X)` needs **real USDC X** to cancel matched debt. Then vault can withdraw X to Landing.
- Net: you spend X USDC to unlock ≈ X from shares. **Does not mint Circle USDC.** It converts locked vault claim into Landing cash once idle exists.
- `stayIdle(Y)` with fresh USDC creates unmatched idle Y → unlocks up to Y of share withdraw **without** needing to repay first (if Morpho liquidity is the vault’s book).

---

## Addresses

| | |
|--|--|
| HOT | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| Landing | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| yRSS | `0xF80C0529bD94C773844E459853CD91B9263dD525` |
| Park market | `0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88` |
| Retired gasPark helper | `0xe87e7e4cdb320ebd761bf7ef8900918d62960be8` |

---

## Deploy both

```bash
cd king-pod
KING_GO=1 forge script script/FireStayIdleShares.s.sol:FireStayIdleDeploy \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

Then **once**: `yRSS.approve(STAY_IDLE, max)` and `yRSS.approve(LIBERATOR, max)` from HOT (fire scripts do this on pull/liberate).

---

## Path A — stayIdle then peel shares

```bash
# Fund HOT with USDC, then:
KING_GO=1 FIRE_STAY=1 STAY_IDLE=0x… AMT=2000000000000 PULL_SHARES=1 \
  forge script script/FireStayIdleShares.s.sol:FireStayIdle \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

## Path B — repay wedge + liberate existing shares

```bash
# Needs USDC on HOT equal to repay wedge (opens idle = cancels park debt):
KING_GO=1 FIRE_LIB=1 LIBERATOR=0x… REPAY=1000000000000 LIBERATE=0 \
  forge script script/FireStayIdleShares.s.sol:FireLiberateShares \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

## Path C — robot poke (idle already open)

```bash
KING_GO=1 FIRE_POKE=1 LIBERATOR=0x… \
  forge script script/FireStayIdleShares.s.sol:FirePokeLiberate \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

---

## Hard rules

1. `borrow` / `gasPark` **revert** on both contracts.
2. Never re-borrow vault liquidity to 100% util for “payroll.”
3. Landing must receive Circle USDC — kingdom eUSD/gUSD is not bills cash.

## Tests

```bash
forge test --match-contract CrownStayIdlePullerTest -vv
```
