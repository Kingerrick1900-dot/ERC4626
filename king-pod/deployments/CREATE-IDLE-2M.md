# CROWN CREATE IDLE — $2M rail

**Status:** CODE READY · deploy gated `KING_GO=1` · fire gated `FIRE_IDLE=1`  
**Branch:** `cursor/morpho-create-idle-2m-4f7f`  
**Law:** Idle only exists if unmatched USDC sits in Morpho. Direct supply. Not yRSS deposit.

---

## What it does

`CrownCreateIdle` — sibling idle-fill to helper `0xe87e…62960be8`.

1. King rails **$2M USDC** into the contract (or approve + `createIdle`)
2. `createIdle(2e6*1e6)` → `Morpho.supply` **direct** into RSS market `0x41c08085…` (yRSS park book)
3. Market idle becomes real → `yRSS.maxWithdraw(hot)` opens
4. `pull100ToLanding(0)` → full unlocked cash to Landing

No flash. No ZK fake balance. ZK attest is separate if used for OTC rail later.

---

## Addresses

| | |
|--|--|
| HOT | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| Landing | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| yRSS | `0xF80C0529bD94C773844E459853CD91B9263dD525` |
| Target Morpho market | `0x41c08085ddcfd1dc1c5eb82d7dc031593d1a1a831958380e8b60469c45bf7d88` |
| Old helper (gasPark→yRSS) | `0xe87e7e4cdb320ebd761bf7ef8900918d62960be8` — do **not** use for this path |

---

## Deploy

```bash
cd king-pod
KING_GO=1 forge script script/FireCreateIdle.s.sol:FireCreateIdleDeploy \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

## Fire $2M

```bash
# 1) Fund HOT with $2M USDC (wire / OTC / other)
# 2) Approve + createIdle
KING_GO=1 FIRE_IDLE=1 CREATE_IDLE=0x… AMT=2000000000000 \
  forge script script/FireCreateIdle.s.sol:FireCreateIdle2M \
  --rpc-url $BASE_RPC_URL --broadcast --slow

# 3) After idle proves, pull 100% (set PULL100=1 or second call)
KING_GO=1 FIRE_IDLE=1 CREATE_IDLE=0x… AMT=2000000000000 PULL100=1 \
  forge script script/FireCreateIdle.s.sol:FireCreateIdle2M \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```

King must `yRSS.approve(CREATE_IDLE, max)` before pull (script does this when `PULL100=1`).

---

## Blockers right now

- HOT USDC = **$0** — need **$2M** on hot (or sent to the new contract) before fire
- HOT ETH ~0.00013 — enough for deploy at Base fees; top up if needed
- Old helper lacks `createIdle` / `pull100ToLanding` — this new contract is the rail

## Tests

```bash
forge test --match-contract CrownCreateIdleTest -vv
```
