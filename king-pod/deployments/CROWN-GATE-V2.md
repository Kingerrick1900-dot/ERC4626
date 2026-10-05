# CrownGateV2 — King Morpho gate (sovereign RSS/USDC)

**Mode:** READY · King authority only · no audit gates  
**Market:** `0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b`  
**Oracle:** `CrownOracle` `0x22E2F66a26eA8d01E0Bb4154ef4DfB0304a34f2d` @ **$50,000**

---

## What it is

`CrownGateV2` is the King's exclusive Morpho operator for the sovereign book:

| Action | Function |
|--|--|
| Post RSS | `supplyCollateral(amount)` |
| Borrow USDC | `borrowUSDC(assets, to)` |
| Repay | `repayUSDC(assets)` |
| Free RSS | `withdrawCollateral(amount, to)` |
| Pause supply/borrow | `setPaused` |
| King succession | `initiateKingTransfer` / `acceptKingship` |

Position `onBehalf` = **the gate**. King alone.

---

## Adopt Path B collateral

Path B posted **~222,521.94 RSS** on Morpho **as HOT** (not the migrator).  
Fire script withdraws that collateral to HOT, then `supplyCollateral` through the gate.

```
FIRE_CROWN_GATE_V2=1
# optional: GATE_ONLY=1          deploy only
# optional: BORROW_USDC=<6dec>   borrow after adopt (needs market cash)
```

```bash
source /tmp/fire.env
cd king-pod
forge script script/FireCrownGateV2.s.sol:FireCrownGateV2 \
  --rpc-url "$BASE_RPC" --broadcast -vvvv
```

---

## Notes

- Struct `MarketParams` is rebuilt from immutables (`marketParams()`) — Solidity has no immutable structs.
- Uses `king-pod` `Core.sol` (no OpenZeppelin remapping required).
- Sovereign market may have **zero supplier cash** until seeded; adopt works without cash; `BORROW_USDC` needs liquidity on market `0x1293…`.
- Fork proof: `forge test --match-contract SimCrownGateV2 -vv`

```
CROWN_GATE_V2=READY
SOVEREIGN=0x1293…2f7b
ORACLE=0x22E2…4f2d
KING=0x6708…a7d1
```
