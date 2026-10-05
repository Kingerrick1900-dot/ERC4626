# FIRE — King rotation HOT → Landing (CrownGateV2)

**Gate:** `0x76fa390951fA31185490378F46B6e9F05bA4bC3b`  
**From (operational):** HOT `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1`  
**To (cold / sovereign):** Landing `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357`

---

## Status: **INITIATED** (accept pending Landing signature)

**Builder handoff (2 tx):** `HANDOFF-KING-ROTATE-2TX.md`

| Step | Action | Status |
|--|--|--|
| 1 | `initiateKingTransfer(Landing)` from HOT | ✅ **Live** |
| 2 | `acceptKingship()` from Landing | ⏳ Pending |
| 3 | `setOperator(HOT, true)` from Landing | ⏳ Pending |
| 4 | Verify HOT cannot `setPaused` / `initiateKingTransfer` | ⏳ After step 2 |

### Tx

| Step | Tx |
|--|--|
| **initiateKingTransfer** | [`0x3847bba0…751e`](https://basescan.org/tx/0x3847bba0fbf59655123f497043001fc9741733588b940487be98cd77896c751e) |

### On-chain (post-initiate)

| Field | Value |
|--|--|
| `king()` | HOT (until Landing accepts) |
| `pendingKing()` | **Landing** `0x5Adcea…2357` |

---

## Complete rotation

**Option A — agent (preferred):** add `LANDING_PRIVATE_KEY` to environment secrets, then:

```bash
cd king-pod
FIRE_KING_ROTATE=1 PHASE=accept \
  forge script script/FireKingRotate.s.sol:FireKingRotate \
  --rpc-url "$BASE_RPC_URL" --broadcast --slow --private-key "$LANDING_PRIVATE_KEY"
```

**Option B — Landing cold sign:**

```bash
cast send 0x76fa390951fA31185490378F46B6e9F05bA4bC3b "acceptKingship()" \
  --rpc-url "$BASE_RPC_URL" --private-key "$LANDING_PRIVATE_KEY"

cast send 0x76fa390951fA31185490378F46B6e9F05bA4bC3b \
  "setOperator(address,bool)" 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1 true \
  --rpc-url "$BASE_RPC_URL" --private-key "$LANDING_PRIVATE_KEY"
```

---

## Separation of powers (after accept)

| Wallet | Role |
|--|--|
| **Landing** | King — `setPaused`, `initiateKingTransfer`, `resetApprovals`, `rescueToken`, `withdrawCollateral` |
| **HOT** | Gate **operator** — `borrowUSDC` / `supplyCollateral` via operator path (with ZK) |
| **CombinedFire** | Existing gate operator for matched fires (unchanged until Landing rewires) |

Fork proof: `forge test --match-test test_king_rotation_hot_to_landing`

```
KING_ROTATE=INITIATED
PENDING_KING=0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357
TX_INIT=0x3847bba0fbf59655123f497043001fc9741733588b940487be98cd77896c751e
```
