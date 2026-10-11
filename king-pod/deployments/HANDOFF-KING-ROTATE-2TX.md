# HANDOFF — Two-Transaction King Rotation

**acceptKingship + setOperator — Finalizing Sovereign Separation**  
**PR:** [#195](https://github.com/Kingerrick1900-dot/ERC4626/pull/195)  
**Companion:** `FIRE-KING-ROTATE.md` · `HANDOFF-BUILDER-COVER.md`

---

## The State

| Field | Value |
|--|--|
| `initiateKingTransfer(Landing)` | ✅ Executed from HOT · [`0x3847bba0…751e`](https://basescan.org/tx/0x3847bba0fbf59655123f497043001fc9741733588b940487be98cd77896c751e) |
| `king()` | **HOT** `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` (until Landing accepts) |
| `pendingKing()` | **Landing** `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| Gate | `0x76fa390951fA31185490378F46B6e9F05bA4bC3b` |

---

## The Two Transactions (Landing cold only)

### Transaction 1 — Accept the throne

```
To:     0x76fa390951fA31185490378F46B6e9F05bA4bC3b
Function: acceptKingship()
Value:  0
Signer: Landing 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357
```

### Transaction 2 — Set HOT as operator

```
To:     0x76fa390951fA31185490378F46B6e9F05bA4bC3b
Function: setOperator(0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1, true)
Value:  0
Signer: Landing (now King)
```

**Cast (cold wallet):**

```bash
export GATE=0x76fa390951fA31185490378F46B6e9F05bA4bC3b
export HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
export RPC="$BASE_RPC_URL"

cast send $GATE "acceptKingship()" --rpc-url "$RPC" --private-key "$LANDING_PRIVATE_KEY"
cast send $GATE "setOperator(address,bool)" $HOT true --rpc-url "$RPC" --private-key "$LANDING_PRIVATE_KEY"
```

**Agent script (both txs, one broadcast):**

```bash
cd king-pod
FIRE_KING_ROTATE=1 PHASE=accept \
  forge script script/FireKingRotate.s.sol:FireKingRotate \
  --rpc-url "$BASE_RPC_URL" --broadcast --slow --private-key "$LANDING_PRIVATE_KEY"
```

---

## The Result

| Role | Wallet | Authority |
|--|--|--|
| **King** | Landing `0x5Adcea…2357` | `setPaused`, `initiateKingTransfer`, `resetApprovals`, `rescueToken`, `supplyCollateral`, `repayUSDC`, `withdrawCollateral` |
| **Operator** | HOT `0x6708…a7d1` | `borrowUSDC` (ZK-gated) · day-to-day draws via gate operator path |
| **Fire contracts** | e.g. CombinedFire `0x37C9…646` | Remain gate operators until Landing rewires `setOperator` |

If HOT is compromised, attacker **cannot** pause, transfer kingship, reset approvals, or rescue — only Landing (King) can.

**Post-rotation verify:**

```bash
cast call $GATE "king()(address)" --rpc-url "$RPC"          # → Landing
cast call $GATE "pendingKing()(address)" --rpc-url "$RPC"   # → 0x0
cast call $GATE "operator(address)(bool)" $HOT --rpc-url "$RPC"  # → true
```

---

## The Doctrine (unchanged)

| Rule | Enforcement |
|--|--|
| ZK every fire | `ZK_SHIELD=1` mandatory |
| No transparent path | `TRANSPARENT_OK=0` · `NO_ZK=0` |
| Quantum signing | RSS rails + WalletGate attestations |
| Proven operator | `isProven(HOT)` on ZK fire paths |

---

## Post-rotation ZK (required before gate fires)

`CrownGateV2` `whenZkFire` checks **`isProven(king)`**, not HOT. After accept, `king = Landing`.

| Wallet | `isProven` (WalletGate `0x3fF6…`) |
|--|--|
| HOT | **true** (live) |
| Landing | **false** (live) |

**Before** `borrowUSDC` / CombinedFire / cover: attest **Landing** on WalletGate (same doctrine as HOT) or gate ZK fires **revert `NotProven`**.

---

## Builder's next steps

1. Landing signs **Tx 1** — `acceptKingship()`
2. Landing signs **Tx 2** — `setOperator(HOT, true)`
3. Confirm on-chain — `king()` → Landing · `operator(HOT)` → true
4. **ZK-attest Landing** on WalletGate · confirm `isProven(Landing) == true`
5. Cover phase — `fireWithCover` when HOT ≥ **$2M USDC** · `FIRE_KINGS_COMBINED=1` · `ZK_SHIELD=1` · `MODE=cover`

---

## Status

| Item | State |
|--|--|
| Initiate | ✅ Live |
| Accept + operator | ⏳ Awaiting Landing signatures / `LANDING_PRIVATE_KEY` |

```
HANDOFF=KING_ROTATE_2TX
TX_INIT=0x3847bba0fbf59655123f497043001fc9741733588b940487be98cd77896c751e
LANDING=0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357
HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
GATE=0x76fa390951fA31185490378F46B6e9F05bA4bC3b
```
