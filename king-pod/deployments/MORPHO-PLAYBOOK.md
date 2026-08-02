# Morpho Playbook — King is legitimate

Morpho’s design:

1. Post proven collateral (Elepan on ELE/USDC — already live)  
2. Borrow USDC  
3. **Keep** it on Landing for bills  

**Forbidden:** borrow → own vault recycle → debt with no cash.

## Armed (real size — not dust)

| Play | Script |
|--|--|
| ELE coll → USDC → Landing KEEP | `FireMorphoOpsDraw.s.sol` |
| Blue USDC supply opens idle | `FireMorphoBlueSupply.s.sol` |
| Direct borrow → wallet KEEP | `FireDirectBorrow.s.sol` |

```bash
KING_GO=1 FIRE_MORPHO_OPS=1 BORROW_USDC=500000000000 \
  forge script script/FireMorphoOpsDraw.s.sol:FireMorphoOpsDraw \
  --rpc-url $BASE_RPC --broadcast --slow
```

Success = Landing USDC up by the borrow. No dust markets. No vault recycle.
