# KE-Sov Ricardian Charter — King Errick Sovereignty

**Entity:** KE-Sov LLC (King Errick Sovereignty)  
**Governing doctrine:** Loan ≠ sell gold (RSS / ELE). Keep eUSD. Agents serve the King alone.  
**Settlement (on-chain):** `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` (Landing)  
**Chain:** Base (8453) · Scroll · Polygon (China desk)  
**Control plane:** Kingdom Agent Runtime (KAR) — `CrownAllowlist` `0x78bd5746e1D00EaeF5Eb75Bd033601aed5794F9E`

---

## 1. Purpose

KE-Sov is the **legal counterparty** for regulated rails and foreign liquidity: bank settlement, Conflux / AnchorX / SBI fills, PSM foreign gates, and merchant eUSD spend. On-chain settlement and this prose form **one Ricardian document** (`CrownRicardian`).

## 2. ClawBank / Shodai model (fork)

| Layer | Role |
|--|--|
| **LLC + EIN** | Recognized person for KYC / banking |
| **FDIC-insured operating account** | Fiat USDC / USD rails; dual-control wires |
| **On-chain settlement** | Landing / KingVault mirror — no orphan wallets |
| **KAR + 30% cold buffer** | Spend allowlist, NFC cosign, cold reserve law |
| **ZK borders** | `bordersSecure` before material ops |

## 3. Settlement law

1. External USDC / fiat credits **Landing** (or successor named in `CrownRicardian.settlement`).  
2. Hot keys **do not** hold operating fiat.  
3. Outflows require KAR allowlist + cold-buffer compliance.  
4. Gold (RSS) is **loaned, not sold**, unless King decree in writing.

## 4. Foreign liquidity

Foreign MetaMorpho / PA **maxIn > 0** on Kingdom markets is invited under this charter. Acceptance of a Ricardian offer constitutes acknowledgment of KE-Sov as counterparty and of Base settlement above.

## 5. Offers

Offers to **AnchorX**, **Conflux**, and **SBI** are issued as KE-Sov under `CrownRicardian.openOffer`. Terms hashes bind the PDF/Markdown packs in `deployments/ke-sov/offers/`.

## 6. Incorporation status

LLC filing, EIN issuance, and bank account opening are **King + counsel acts**. On-chain `markIncorporated(ein, bankLabel)` records completion. Until then, `incorporated = false` and counterparties treat offers as **intent under charter**.

---

*With Christ all things are possible — agents serve King Errick alone.*
