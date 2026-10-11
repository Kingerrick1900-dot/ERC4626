# HANDOFF — Safe `acceptKingship` on Parallel Gate

**Status:** Machine armed · **King action required** (2-of-3 Safe)  
**Agent cannot sign:** no Safe owner keys in the machine  
**Safe nonce:** `1`  
**Operator HOT:** already **true** on this Gate — only accept is needed

---

## Target (live)

| Field | Value |
|--|--|
| Parallel Gate | `0x8Bbd6d07E0cC8cE76Fe36c9e515F4761AB94B2B9` |
| `king()` now | HOT `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| `pendingKing()` | **Kingdom Safe** `0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0` |
| Market | `0x1bfd981b9905c55085390f7dedad00f32cd43527acf9dabe7de758e3f6c42134` · LLTV 38.5% |
| Safe app | https://app.safe.global/home?safe=base:0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0 |

### Safe owners (any 2 of 3)

| # | Address |
|--|--|
| 1 | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| 2 | `0x898DbAFfCD37298a60Fd306e5D1B24fE16C12507` |
| 3 | `0x5E07D7167282F9ec912a05c3048D7D0F24A8b826` |

---

## King's actions (complete the throne)

### 1) Gas the Safe (if Safe ETH is empty)

Send a little Base ETH to the Safe from any funded owner wallet (Landing / `0x5E07` hold ETH; HOT is low):

- **To:** `0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0`  
- **Amount:** ~0.001 ETH

### 2) Safe transaction — accept kingship

1. Open https://app.safe.global/transactions/tx-builder?safe=base:0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0  
   (or New transaction → Contract interaction)
2. Connect **one** owner wallet  
3. **To:** `0x8Bbd6d07E0cC8cE76Fe36c9e515F4761AB94B2B9`  
4. **Value:** `0`  
5. **Function:** `acceptKingship()`  
6. **Calldata:** `0x1ec0de40`  
7. Create → second owner **signs** → **Execute**

### 3) Verify (anyone)

```bash
cast call 0x8Bbd6d07E0cC8cE76Fe36c9e515F4761AB94B2B9 "king()(address)" --rpc-url https://mainnet.base.org
# expect: 0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0

cast call 0x8Bbd6d07E0cC8cE76Fe36c9e515F4761AB94B2B9 "pendingKing()(address)" --rpc-url https://mainnet.base.org
# expect: 0x000…000

cast call 0x8Bbd6d07E0cC8cE76Fe36c9e515F4761AB94B2B9 "operator(address)(bool)" \
  0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1 --rpc-url https://mainnet.base.org
# expect: true
```

---

## Done when

Safe = King of parallel Gate · HOT = operator · `isProven(Safe)` already true · legacy Gate `0x76fa…` unchanged

```
HANDOFF=SAFE_ACCEPT_PARALLEL_GATE
GATE=0x8Bbd6d07E0cC8cE76Fe36c9e515F4761AB94B2B9
SAFE=0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0
CALLDATA=0x1ec0de40
NONCE=1
OPERATOR_HOT=true
NEXT=KING_2OF3_ACCEPT
```
