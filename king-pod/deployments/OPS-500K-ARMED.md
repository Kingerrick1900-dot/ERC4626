# Ops $500k USDC → Landing

**Gate: live broadcast ONLY on King GO.**  
Requires `KING_GO=1` **and** the path `FIRE_*=1`. No path flag = no broadcast. Env leftover `KING_GO=1` alone is not fire.

Landing (cold): `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357`  
Ops cash = **USDC only**.

## Armed fires (King GO + flag)

| # | Fire | Flag | Needs at send | Lands |
|--|--|--|--|--|
| 0 | `FireAcceptYeleCap` | `FIRE_ACCEPT_CAP=1` | pending unlock (`validAt` passed) | enables WETH sink |
| 1 | `FireElepanBills` / redeem | `FIRE_ELE_BILLS=1` | yELE on hot | USDC → Landing |
| 2 | `FireElepanBorrowUsdc` | `FIRE_BORROW=1` | ELE/USDC idle ≥ ask | USDC → Landing |
| 3 | `FireMorphoOpsDraw` | `FIRE_MORPHO_OPS=1` | ELE/USDC idle ≥ ask | USDC → Landing |
| 4 | `FireZkCreditDraw` | `FIRE_ZK_CREDIT=1` | credit pool USDC > 0 | USDC → Landing |
| 5 | `FireMatcherComplete` | `FIRE_LOAN_MATCH=1` | `MATCHER_KEY` + matcher USDC | USDC → Landing |
| 6 | Share exit/extract | `FIRE_SHARE_EXIT=1` / `FIRE_YELE_SHARES=1` | buyer or Landing key | USDC → Landing |
| 7 | `FireOpsFive` cleanse | `FIRE_OPS_FIVE=1` `CLEANSE=1` | yELE WETH/USDC **accepted** | then redeem/borrow rails |
| 8 | `FireOpsFive` side unwind | `FIRE_OPS_FIVE=1` (default no CLEANSE) | WETH/cbBTC seeds | dust WETH → borrow if any |

## King GO commands (copy after GO)

```bash
# A) After unlock (~2026-07-26T19:08:47Z) — accept WETH/USDC sink
KING_GO=1 FIRE_ACCEPT_CAP=1 forge script script/FireAcceptYeleCap.s.sol:FireAcceptYeleCap \
  --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY

# B) Cleanse ELE/USDC self-seed via yELE reallocate+skim (needs A)
KING_GO=1 FIRE_OPS_FIVE=1 CLEANSE=1 forge script script/FireOpsFive.s.sol:FireOpsFive \
  --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY

# C) When ELE/USDC idle ≥ $500k
KING_GO=1 FIRE_BORROW=1 BORROW_USDC=500000000000 forge script script/FireElepanBorrowUsdc.s.sol \
  --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY

# D) Credit / matcher when funded
KING_GO=1 FIRE_ZK_CREDIT=1 ASK_USDC=500000000000 forge script script/FireZkCreditDraw.s.sol \
  --rpc-url $RPC_URL --broadcast --private-key $PRIVATE_KEY
```

Preflight (no broadcast): omit `FIRE_*=1` where supported, or run without `--broadcast`.

## Live meters (2026-07-24)

| Meter | Value |
|--|--|
| Landing USDC | ~$10.37 |
| Hot Morpho ELE/USDC debt | ~$13.001M · coll ~20.15M ELE · HF ~1.55 |
| ELE/USDC idle | ~$0 (100% util) |
| WETH/USDC idle | ~$7.7M (needs WETH coll) |
| Credit `maxBorrow` | 0 |
| yELE TVL | ~$13.001M · shares almost all on Landing |
| yELE `submitCap` WETH/USDC $50M | pending · `validAt` `1785092927` (~47.9h) |
| yELE `submitTimelock` 1d | pending · same window |
| ELE DEX pools (Aero/Uni) | **none** — cannot sell Landing ELE for USDC on-chain |
| Side seeds ELE/WETH + ELE/cbBTC | matched · free WETH after unwind ≈ dust |

## Physics (why not live now)

- Open Morpho debt already received its USDC at borrow time (flash repaid into yELE).
- Further `borrow` needs **idle** in ELE/USDC — currently ~0.
- yELE single-market `reallocate` → `InconsistentReallocation` until WETH/USDC cap accepted.
- Matched WETH/cbBTC loops do not free ops-scale WETH.
- No `LANDING_KEY` → cannot redeem Landing yELE shares from hot.

**First GO after unlock:** `FIRE_ACCEPT_CAP` → `FIRE_OPS_FIVE CLEANSE=1` → redeem/borrow rails to Landing USDC.
