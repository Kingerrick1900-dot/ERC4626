# ORDER — Complete King rotation (Landing sovereign)

**Status:** ACTIVE · not deferred · pendingKing = Landing  
**Gate:** `0x76fa390951fA31185490378F46B6e9F05bA4bC3b`  
**King's will:** Landing = King · HOT = operator only · eliminate single point of failure

---

## Live (restored)

| Field | Value |
|--|--|
| `king()` | HOT (until Landing accepts) |
| `pendingKing()` | **Landing** `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| Re-initiate (restore) | [`0x197b23ba…2e3d`](https://basescan.org/tx/0x197b23ba247f322b6799bee9bed102df34444986578d127ec032c4bb95f42e3d) |

**Do not clear `pendingKing` again.**

---

## Execution (bash — sealed chamber)

1. King adds **`LANDING_PRIVATE_KEY`** to Cursor sealed secrets (not chat).
2. King says **Fire**.
3. Agent runs:

```bash
cast send 0x76fa390951fA31185490378F46B6e9F05bA4bC3b "acceptKingship()" \
  --rpc-url https://mainnet.base.org --private-key "$LANDING_PRIVATE_KEY"

cast send 0x76fa390951fA31185490378F46B6e9F05bA4bC3b \
  "setOperator(address,bool)" 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1 true \
  --rpc-url https://mainnet.base.org --private-key "$LANDING_PRIVATE_KEY"
```

4. Verify: `king() == Landing` · `operator(HOT) == true` · `pendingKing() == 0`
5. King **deletes** `LANDING_PRIVATE_KEY` from secrets immediately.

---

## Result after Fire

| Role | Wallet |
|--|--|
| King | Landing — pause / transfer / rescue / repay / withdraw |
| Operator | HOT — ZK-gated `borrowUSDC` only |

```
ORDER=COMPLETE_ROTATION
PENDING=Landing
PATH=SEALED_CHAMBER_BASH
NO_CLEAR=1
```
