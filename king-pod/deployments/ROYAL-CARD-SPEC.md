# Royal Card — Kingdom NFC spend rail (Phase-4 preview)

**Status:** Spec + `RoyalCard.sol` — freeze build · no China manufacturing yet  
**Doctrine:** Original Crown design. **Not** a Lakala (or any) patent fork.

---

## Physical

| Layer | Spec |
|--|--|
| Form | ISO 7810 ID-1 · contactless Type A |
| Secure element | SE with secp256k1 spend key (seed never exported) |
| Face | Kingdom mark · last-4 card id · no private material |
| Cosign | Tap → ECDSA over KAR userOp / tx hash (see `kar/nfc_cosign.md`) |

---

## On-chain (`RoyalCard.sol`)

| Concept | Behavior |
|--|--|
| `cardId` | bytes32 kingdom id |
| `pubKeyHash` | hash of NFC pubkey |
| `dailyLimit` | eUSD 18dp rolling day |
| `spend` | owner pulls eUSD → merchant; optional `bordersSecure` gate |
| Freeze | King `setFrozen` |

Wire later: `CrownPayAdapter` / Open Money merchants · Polygon agent rail.

---

## Build today vs later

| Today (Phase II freeze) | Later (Phase 4 fire) |
|--|--|
| Contract + unit tests | Mainnet deploy multi-chain |
| Spec + KAR cosign stub | SE vendor + card print |
| Testnet issue/spend smoke | China desk distribution |

---

## One-block

```
ROYAL_CARD=kingdom-original NFC eUSD spend
NO lakala-patent-fork
CODE=king-pod/src/royal/RoyalCard.sol
COSIGN=kar/nfc_cosign.md
MFG=Phase4 after float+China GO
```
