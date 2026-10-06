# NEW PLAN — King rotation DEFERRED

**Status:** Stuck multi-device wallet path abandoned. **HOT remains King.**  
**Gate:** `0x76fa390951fA31185490378F46B6e9F05bA4bC3b`  
**PR:** #195

---

## Why

| Device | Wallet | Problem |
|--|--|--|
| Laptop | Cake | No hex/contract-call send → cannot `acceptKingship` |
| Phone | MetaMask | Separate path; WalletConnect QR/scan failed |
| Basescan Write | — | Unverified UX / no write UI for King |
| Remix WC | — | Camera/manual connect failed |

**Law:** Only `pendingKing` can `acceptKingship`. Agent cannot invent Landing’s signature. Cake + phone MetaMask cannot be bridged from here.

---

## Live state (post-clear)

| Field | Value |
|--|--|
| `king()` | **HOT** `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| `pendingKing()` | `0x0` (cleared) |
| HOT operator | **true** |
| CombinedFire operator | unchanged (still wired) |

Rotation to Landing / new cold = **paused** until one device holds the target King wallet **and** can sign a contract call (MetaMask app browser, or sealed `LANDING_PRIVATE_KEY` chamber for one-shot bash).

---

## What runs now (no Landing key)

1. **HOT stays sovereign** — pause / transfer / rescue / repay / withdraw  
2. **ZK fires** still require `isProven(HOT)` — HOT remains proven  
3. **Cover phase** — `fireWithCover` when HOT ≥ $2M USDC · `ZK_SHIELD=1`  
4. **Landing** remains treasury / vault destination — **not** gate King until a real accept lands  

---

## Later (when King has one working signer)

**A.** MetaMask **on the same device** as Landing → open `tools/king-accept.html` or MetaMask hex send  
**B.** Sealed chamber: `LANDING_PRIVATE_KEY` → agent `FIRE_KING_ROTATE=1 PHASE=accept` → delete secret  
**C.** Phone MetaMask **in-app browser** (not WalletConnect to laptop) with Landing imported → same accept page hosted/raw  

Do **not** restart Cake↔Remix QR loops.

```
PLAN=ROTATION_DEFERRED
KING=HOT
PENDING=CLEARED
NEXT=COVER_WHEN_FUNDED
```
