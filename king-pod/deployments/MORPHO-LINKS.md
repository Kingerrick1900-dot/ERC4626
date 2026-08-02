# Morpho Links — Ops Cash (No Outside-Approval Theater)

Morpho Blue **already allows** the custom stack Kingdom built. The failure was forcing **one** seed pattern (self-seed → vault → wait) and skipping the disbursement link.

## Mathematical mismatch (live)

| Side | Amount |
|--|--|
| Morpho ELE debt (hot) | **~$14,000,000** USDC |
| yELE supply into same market | **~$14,000,000** USDC (Landing owns shares) |
| Idle in ELE/USDC | **$0** |
| Spendable USDC (hot+Landing) | **~$5.65** |
| Oracle-proven posted coll | ~20.0M Elepan @ $1 · LLTV 77% |
| Unused headroom on posted coll | **~$1,399,564** |
| Free Elepan on hot (unposted) | **~$55.98M** → ~**$43.1M** more capacity **if idle exists** |

Debt was generated from an asset. Cash was not kept. That is the mismatch.

## Morpho-allowed chain (the links)

```
1. Custom market      ELE/USDC · oracle $1 · LLTV 77%     LIVE
2. Collateral proof   Morpho.position + oracle.price()   LIVE
3. Capacity           min(LLTV×coll − debt, market idle)
4. Disburse           Morpho.borrow(..., receiver=Landing)
5. KEEP               USDC stays on Landing — never vault re-supply
```

Morpho does **not** require Gauntlet approval for step 4 on a live Blue market.  
Morpho does **not** require a “matcher” product for step 4.  
Permissionless `supply(USDC)` into the Blue market (anyone) opens idle — that is Morpho’s pattern, not an app gate.

## The ONE wrong pattern (do not repeat)

```
borrow(USDC) → deposit yELE → yELE supplies same market → idle 0 → debt remains → ops $0
```

That is not how Morpho designs borrower liquidity. That is a closed loop.

## Ops fire (when idle > 0)

```bash
KING_GO=1 FIRE_MORPHO_OPS=1 BORROW_USDC=500000000000 \
  forge script script/FireMorphoOpsDraw.s.sol:FireMorphoOpsDraw \
  --rpc-url $BASE_RPC --broadcast --slow
```

Hard rules in script: receiver = Landing · no vault deposit · refuse if Landing USDC does not rise.

## Open idle without “curator packet” theater

Anyone (including King when holding fresh USDC) can supply the Blue market directly:

```bash
KING_GO=1 FIRE_MORPHO_SUPPLY=1 SUPPLY_USDC=<raw6> \
  forge script script/FireMorphoBlueSupply.s.sol:FireMorphoBlueSupply \
  --rpc-url $BASE_RPC --broadcast --slow
```

Then `FIRE_MORPHO_OPS` same block. Own curator vault is optional — not a blocker for Blue borrow.
