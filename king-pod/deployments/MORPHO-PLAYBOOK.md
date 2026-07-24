# Morpho Playbook — King is legitimate

King is running **Morpho’s playbook**, not a crime:

1. Post accepted collateral (oracle-proven)  
2. Borrow USDC from Morpho Blue  
3. **Keep** USDC on Landing for operating bills  

That is how Morpho is designed.

## Forbidden (the abuse loop — not Morpho)

Borrow → deposit **own** vault → same dollars re-supply the same market → debt stays, bills unpaid.

Self-seed recycle is frozen. **Morpho borrow is not frozen.**

## Plays other scribes already wrote (use these)

| Play | Script / sheet | Morpho-legal |
|--|--|--|
| ELE coll → USDC → Landing KEEP | `FireMorphoOpsDraw.s.sol` | Yes |
| Permissionless Blue USDC supply (opens idle) | `FireMorphoBlueSupply.s.sol` | Yes |
| Direct RSS → wallet KEEP (no vault) | `FireDirectBorrow.s.sol` | Yes |
| Whale markets (cbBTC/WETH idle depth) | `WHALE-ENG-BRIEF.md` | Yes — needs bankable coll |

## Live book (honest)

| Item | Now |
|--|--|
| ELE Morpho debt | ~$14.0M |
| ELE idle | $0 (prior recycle filled both sides) |
| Posted coll headroom | ~$1.4M |
| Free Elepan on hot | ~56M |
| cbBTC market idle | **~$153M** |
| WETH market idle | **~$8M** |
| Hot cbBTC / WETH | dust / 0.002 |

## Fire when idle or whale coll is ready

```bash
# Morpho playbook — ELE market
KING_GO=1 FIRE_MORPHO_OPS=1 BORROW_USDC=500000000000 \
  forge script script/FireMorphoOpsDraw.s.sol:FireMorphoOpsDraw \
  --rpc-url $BASE_RPC --broadcast --slow
```

Success = Landing USDC up. No vault re-deposit. No treating King like a criminal for borrowing.
