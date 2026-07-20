# Buffer hunt — report for King

**Asked:** Find the buffer. Bring it back.

**Found:** There is **no usable USDC access buffer** in Kingdom wallets or the RSS/USDC Morpho market today.

| Place | USDC (approx) | Usable as $500k / 20%-of-$9M buffer? |
|-------|----------------|--------------------------------------|
| Hot | **$0.10** | No |
| Cold Landing | **$1** | No (dust) |
| Old Cake | **$0** | No |
| Vault V2 TVL | **~$1** (dead seed) | No |
| Vault V2 idle cash | **$0** | No |
| Morpho RSS/USDC market idle | **~$1** | No |
| Exit freer / seeders | **$0** | No |
| Morpho *global* USDC | ~$187M | **Not ours** — other markets |

**RSS on hot (~18.5M)** = collateral, not a USDC buffer.

**yRSS V1** still shows a share balance on hot; that was the old circular book — **not** liquid wallet USDC and **not** the V2 access buffer.

---

## What this means

- Last successful **$9M-style** loan did **not** leave a cash cushion behind. Matched flash/deposit/borrow → util ~100% → buffer = **$0**.
- **80% / 20% idle** would *create* a buffer only if that 20% is funded (King cash or outside suppliers). It is **not sitting somewhere waiting**.
- **$500k deallocate** needs either **≥$500k market idle** after the loan, or **≥$500k IKR USDC**. Neither exists on-chain for us right now.

**Bottom line for King:** Buffer not found in the kingdom. It must be **created** (outside Morpho deposits, or real USDC for IKR/20% gap) — not recovered from a hidden wallet.
