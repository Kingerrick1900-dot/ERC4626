# HANDOFF — King rotation to NEW cold wallet

**New cold King:** `0x5E07D7167282F9ec912a05c3048D7D0F24A8b826`  
**HOT (operator after accept):** `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1`  
**Gate:** `0x76fa390951fA31185490378F46B6e9F05bA4bC3b`  
**PR:** [#195](https://github.com/Kingerrick1900-dot/ERC4626/pull/195)

---

## Live state

| Field | Value |
|--|--|
| `king()` | HOT (until cold accepts) |
| `pendingKing()` | **New cold** `0x5E07D7167282F9ec912a05c3048D7D0F24A8b826` |
| Prior Landing pending | **Superseded** (Landing is no longer pending) |

### Tx — re-initiate to new cold

| Step | Tx |
|--|--|
| `initiateKingTransfer(0x5E07…b826)` from HOT | [`0xa0d1f809…1a37`](https://basescan.org/tx/0xa0d1f8093747b0170803133ba08a7c2f565673b200a014c9cedfea7c6e551a37) |

---

## Two transactions (from NEW cold only)

### Tx 1 — Accept

```
To: 0x76fa390951fA31185490378F46B6e9F05bA4bC3b
Function: acceptKingship()
Data: 0x1ec0de40
```

### Tx 2 — HOT as operator

```
To: 0x76fa390951fA31185490378F46B6e9F05bA4bC3b
Function: setOperator(0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1, true)
Data: 0x558a72970000000000000000000000006708e21113922ed588bbccaa5ef756becbb2a7d10000000000000000000000000000000000000000000000000000000000000001
```

**Easiest:** Basescan Write Contract (gate verified on Sourcify) → connect **new cold** → click both.  
https://basescan.org/address/0x76fa390951fA31185490378F46B6e9F05bA4bC3b#writeContract

**Or cast (local only):**

```bash
export COLD_KEY=0x...   # new cold — never paste in chat
cast send 0x76fa390951fA31185490378F46B6e9F05bA4bC3b "acceptKingship()" \
  --rpc-url https://mainnet.base.org --private-key $COLD_KEY
cast send 0x76fa390951fA31185490378F46B6e9F05bA4bC3b \
  "setOperator(address,bool)" 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1 true \
  --rpc-url https://mainnet.base.org --private-key $COLD_KEY
```

**Or private chamber:** add secret `COLD_PRIVATE_KEY` / `LANDING_PRIVATE_KEY` = new cold → say **Fire**.

---

## After accept

| Role | Wallet |
|--|--|
| King | `0x5E07…b826` |
| Operator | HOT `0x6708…a7d1` |

**Also:** ZK-attest the new cold on WalletGate before gate fires (`isProven(king)`). Currently **not** proven.

```
HANDOFF=KING_ROTATE_NEW_COLD
PENDING_KING=0x5E07D7167282F9ec912a05c3048D7D0F24A8b826
TX_INIT=0xa0d1f8093747b0170803133ba08a7c2f565673b200a014c9cedfea7c6e551a37
SUPERSEDES=Landing_0x5Adcea
```
