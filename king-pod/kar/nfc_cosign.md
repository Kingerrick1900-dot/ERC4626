# NFC cosign (CN physical layer) — P3 stub

High-risk KAR ops require a second factor:

1. KAR builds tx hash / userOp hash  
2. NFC card taps → returns ECDSA cosign (card never exports seed)  
3. Kingdom Key Vault merges signatures → broadcast  

Policy keys in `policy.json` → `keyPolicy.nfcCosignRequiredFor`.  
Until hardware lands, ops Safe / manual King confirm stands in.
