# HANDOFF — Accept kingship via MetaMask (Landing)

**No Basescan Write needed.** Landing signs inside MetaMask.

| Field | Value |
|--|--|
| Gate | `0x76fa390951fA31185490378F46B6e9F05bA4bC3b` |
| **pendingKing** | **Landing** `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| HOT (operator after) | `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| Re-initiate tx | [`0xa53e94c0…406c`](https://basescan.org/tx/0xa53e94c0b09aab282d1c736f704aa817b722f0052726c41f6641a3bd88e1406c) |

---

## What the King does

1. Open MetaMask → account **Landing** `0x5Adcea…2357` → network **Base**
2. Open the accept page (local file or GitHub raw):

```
king-pod/tools/king-accept.html
```

   Or download/open from the repo branch `cursor/crown-gate-v2-4f7f`.

3. Click **Connect MetaMask** (must show Landing)
4. Click **Accept kingship** → Confirm in MetaMask  
5. Click **Set HOT as operator** → Confirm in MetaMask  

Private key **never** leaves MetaMask. Agent never sees it.

---

## After both succeed

```bash
cast call 0x76fa390951fA31185490378F46B6e9F05bA4bC3b "king()(address)" --rpc-url https://mainnet.base.org
# → Landing
cast call 0x76fa390951fA31185490378F46B6e9F05bA4bC3b "operator(address)(bool)" 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1 --rpc-url https://mainnet.base.org
# → true
```

Say **check again** when done.

```
PENDING=Landing_0x5Adcea
PATH=MetaMask_king-accept.html
```
