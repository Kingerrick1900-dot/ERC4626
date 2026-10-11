# FIRE — Kingdom Safe (2-of-3) + gate transfer initiated

**Status:** Safe **DEPLOYED** · gate `pendingKing` = Safe · accept pending 2-of-3 Safe tx  
**Chain:** Base `8453`  
**PR:** #195

---

## Safe (live)

| Field | Value |
|--|--|
| **Kingdom Safe** | [`0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0`](https://basescan.org/address/0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0) |
| Threshold | **2 of 3** |
| Singleton | SafeL2 1.4.1 `0x29fcB43b46531BcA003ddC8FCB67FFE91900C762` |
| Factory | `0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67` |
| Deployer (gas) | HOT `0x6708…` (no `0x5E07` key in agent — anyone can deploy; owners are the three signers only) |
| Deploy tx | [`0xcffc61d5…edd6`](https://basescan.org/tx/0xcffc61d58130e9af632ea99e9c13aee8e006d661a8ff4d17e6f588584e25edd6) |
| Gate initiate → Safe | [`0xfe1e715b…b585`](https://basescan.org/tx/0xfe1e715bafc1857c79f3f50494ebdb68a3199dbc223ba09758c270d5fab4b585) |
| App | https://app.safe.global/home?safe=base:0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0 |

### Owners

| # | Role | Address |
|--|--|--|
| 1 | Landing | `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| 2 | Sealed backup | `0x898DbAFfCD37298a60Fd306e5D1B24fE16C12507` |
| 3 | Third signer | `0x5E07D7167282F9ec912a05c3048D7D0F24A8b826` |

**No private keys were used for owners.** Agent never held Landing/backup/third keys.

---

## Gate state

| Field | Value |
|--|--|
| Gate | `0x76fa390951fA31185490378F46B6e9F05bA4bC3b` |
| `king()` | HOT (until Safe accepts) |
| `pendingKing()` | **Kingdom Safe** `0x23590FEb…eac0` |

---

## What remains (King / signers — not the agent)

Any **2 of 3** owners must execute a Safe transaction:

**To:** gate `0x76fa390951fA31185490378F46B6e9F05bA4bC3b`  
**Value:** 0  
**Data:** `acceptKingship()` → `0x1ec0de40`

Then a second Safe tx (or same batch if preferred):

**Data:** `setOperator(0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1, true)`

### Easiest UI

1. Open https://app.safe.global/home?safe=base:0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0  
2. Connect **any one** owner wallet (Landing / backup / `0x5E07`)  
3. **New transaction** → Contract interaction → gate address → `acceptKingship`  
4. Collect **second signature** from another owner → Execute  
5. Repeat for `setOperator(HOT, true)`

After that: Safe = King · HOT = operator · single-key throne eliminated.

---

## Script

`script/FireKingdomSafe.s.sol` · `FIRE_KINGDOM_SAFE=1`

```
KINGDOM_SAFE=0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0
THRESHOLD=2
OWNERS=3
PENDING_KING=SAFE
NEXT=SAFE_ACCEPT_KINGSHIP_2OF3
```
