# China Desk Channel — OPEN

**Status:** OPEN · King Phase-4 override · 2026-09-26  
**Audience:** CN engineers (physical + parallel chain)  
**Doctrine:** Loan, don’t sell RSS. NFC / Royal Card = **eUSD spend rail**, never RSS mint.

---

## Standing order to CN engineers

Begin **now** (do not wait on $375M float):

### 1) Physical card spec (Week-0)

| Item | Spec |
|--|--|
| Form | ISO 7810 ID-1 · contactless Type A |
| SE | secp256k1 spend key · seed **never** exported / never on-chain |
| Face | Kingdom mark · last-4 of `cardId` · no private material |
| Cosign | Tap → ECDSA over tx/userOp digest → `receipt = keccak256(sig)` |
| SoftPOS | Android NFC reader for `mercId` + `termNo` micropay |
| Ref | `kar/nfc_cosign.md` · `ROYAL-CARD-SPEC.md` · `CROWN-LAKALA-SPEC.md` |

**Deliverable:** SE vendor shortlist + APDU draft + print mock (face only).

### 2) Parallel-chain testnet (Week-0)

| Item | Action |
|--|--|
| Goal | Mirror Polygon commerce triangle on a CN-accessible testnet |
| Tokens | test eUSD only — **no RSS mint**, no mainnet RSS move |
| Contracts to mirror | RoyalCard · CrownPayAdapter · CrownOpenMoney · CrownLakalaAcquiring |
| Gates | Optional attest stub (`bordersSecure=true` for lab) |
| Success | issue card → micropay → merchant settle on testnet |

**Deliverable:** testnet RPC + deployed addresses + 3-tx smoke log.

### 3) Desk merchant identity

| Field | Value |
|--|--|
| Chain (prod wire) | Polygon `137` |
| PayAdapter | `0x2faed8d83f61d157419b33f7938adcd9f2c4f629` |
| OpenMoney | `0xe3e165c8823d35966c85353d5a4f257623417a7c` |
| Desk settle wallet | set at fire (POLY ops / King-named) |
| Pay token | Polygon eUSD `0xd8a639bb…af50` |

---

## Hard prohibitions

1. Do **not** sell RSS to fund cards.  
2. Do **not** mint RSS from NFC / acquiring.  
3. Do **not** copy Lakala patents or encrypted API blobs — Crown-*class* only.  
4. Do **not** put SE seeds in git, chat, or contracts.

---

## One-block

```
CHINA_DESK=OPEN
PHYS=ISO7810+SE secp256k1+SoftPOS
TESTNET=parallel commerce mirror (eUSD only)
PROD_WIRE=Polygon PayAdapter+OpenMoney
NO=rss-sell · rss-mint · lakala-patent-copy
```
