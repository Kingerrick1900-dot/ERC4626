# KAR NFC cosign stub (Phase-4)

**Status:** Stub only — not hardware manufacturing  
**Doctrine:** Off-chain cosign for RoyalCard / CrownLakala micropay receipts.

---

## Flow

1. SoftPOS / card SE holds secp256k1 spend key (seed never exported).
2. Terminal presents `outTradeNo || mercId || termNo || amount || chainId || acquiring`.
3. SE signs → `receipt = keccak256(abi.encode(sig))` or raw digest hash.
4. On-chain:
   - Direct: `CrownLakalaAcquiring.micropay(..., receipt)`
   - Card: `CrownLakalaCardBridge.payWithCard(..., receipt)`
5. Relayer / KAR runner may submit userOp; cosign proves physical presence.

---

## Not in this stub

- SE vendor selection / APDU profiles  
- China desk distribution  
- Patent-encumbered Lakala protocols  

Wire when Phase 4 unlocked after float + China GO.
