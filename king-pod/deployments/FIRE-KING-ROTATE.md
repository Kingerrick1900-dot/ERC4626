# FIRE — King rotation HOT → new cold (CrownGateV2)

**Gate:** `0x76fa390951fA31185490378F46B6e9F05bA4bC3b`  
**From (operational):** HOT `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1`  
**To (cold / sovereign):** **NEW** `0x5E07D7167282F9ec912a05c3048D7D0F24A8b826`  
**(Landing pending superseded)**

---

## Status: **INITIATED** (accept pending **new cold** signature)

**Builder handoff:** `HANDOFF-KING-ROTATE-NEW-COLD.md`

| Step | Action | Status |
|--|--|--|
| 1a | `initiateKingTransfer(Landing)` from HOT | ✅ Superseded |
| 1b | `initiateKingTransfer(new cold)` from HOT | ✅ **Live** |
| 2 | `acceptKingship()` from **new cold** | ⏳ Pending |
| 3 | `setOperator(HOT, true)` from new cold | ⏳ Pending |
| 4 | Verify HOT cannot `setPaused` / `initiateKingTransfer` | ⏳ After step 2 |

### Tx

| Step | Tx |
|--|--|
| initiate → Landing (old) | [`0x3847bba0…751e`](https://basescan.org/tx/0x3847bba0fbf59655123f497043001fc9741733588b940487be98cd77896c751e) |
| **initiate → new cold** | [`0xa0d1f809…1a37`](https://basescan.org/tx/0xa0d1f8093747b0170803133ba08a7c2f565673b200a014c9cedfea7c6e551a37) |

### On-chain (post-re-initiate)

| Field | Value |
|--|--|
| `king()` | HOT (until new cold accepts) |
| `pendingKing()` | **New cold** `0x5E07…b826` |

---

## Complete rotation

**Option A — agent:** add `COLD_PRIVATE_KEY` (new cold) to secrets, then:

```bash
cd king-pod
FIRE_KING_ROTATE=1 PHASE=accept \
  forge script script/FireKingRotate.s.sol:FireKingRotate \
  --rpc-url "$BASE_RPC_URL" --broadcast --slow --private-key "$COLD_PRIVATE_KEY"
```

**Option B — new cold signs (Basescan Write / cast / chamber):** see `HANDOFF-KING-ROTATE-NEW-COLD.md`

---

## Separation of powers (after accept)

| Wallet | Role |
|--|--|
| **New cold** `0x5E07…b826` | King — `setPaused`, `initiateKingTransfer`, `resetApprovals`, `rescueToken`, `withdrawCollateral` |
| **HOT** | Gate **operator** — `borrowUSDC` via operator path (with ZK) |
| **CombinedFire** | Existing gate operator (unchanged until new King rewires) |

Fork proof: `forge test --match-test test_king_rotation_hot_to_new_cold`

```
KING_ROTATE=INITIATED
PENDING_KING=0x5E07D7167282F9ec912a05c3048D7D0F24A8b826
TX_INIT=0xa0d1f8093747b0170803133ba08a7c2f565673b200a014c9cedfea7c6e551a37
```
