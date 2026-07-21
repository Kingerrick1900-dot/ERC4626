# The Sovereign Liquidity Plan

**Doctrine (King).** Plain text locked. Status mapped to Base.

> Lock RSS collateral (1M) into a live Base CDP to mint kUSD (700k) to hot wallet. Use ZK-proof (`isProven(hot)`) to attest the position to counterparties. They advance USDC against the verified \$700k ticket. Settle via wire, CrownZkCredit, or internal borrow/desk fill. Route funds to KingVault for ops + expansion. Activate fees on markets (BRETT, RSS, new ones) for passive yield. Repeat with loops on external pairs for more depth. ZK ensures private, verifiable trust without full disclosure. This creates self-sustaining treasury fills, daily ops coverage, and scalable market growth while keeping core RSS sovereign.

---

## Status map

| Step | Plan | Status | Live |
|------|------|--------|------|
| 1 | Lock 1M RSS → mint 700k kUSD to hot | **DONE** | CDP `0x9F9356dd8B17f58d03f3Db84e81541cdABBD5768` · kUSD `0x0FEA62084A024544891f03035E85401C2C886c1b` |
| 2 | ZK attest `isProven(hot)` | **DONE** | Gate `0xAf9570a3Fe67988AE1c7d4dA0cD5c54CFE147205` |
| 3 | Counterparties advance USDC vs \$700k ticket | **ARMED** — await fill | Packet `SECURE-700K-TOTAL.md` · `ZK-PROOF-HOW-TO-USE.md` |
| 4 | Settle: wire · Credit V2 `borrowTo(cold)` · desk | **ARMED** | Credit V2 `0x01814e15cF01DEcdC7239b739177C36acaBaBA54` · Desk `0xDbf7C4Ad01418ec1b753fa039d5e5B54aF4C065D` · Cold `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` |
| 5 | Route to KingVault (ops + expansion) | **NEXT** | Landing is cold today; Vault V2 tooling in `vault-v2-tooling/` |
| 6 | Fees on BRETT / RSS / new markets | **PARTIAL** | yRSS 10% fee rail · BRETT market live · harvest → Landing |
| 7 | Loops on external pairs → depth | **NEXT** | Aero RSS/USDC thin · bribe/CDP expand |
| 8 | Core RSS stays sovereign | **LOCKED** | Free RSS still on hot after 1M CDP lock (~15.6M) |

---

## Flow (one page)

```
RSS (sovereign)
  → CDP lock 1M → kUSD 700k @ Fixed $1     [LIVE]
  → ZK isProven(hot) ≥ $700k               [LIVE]
  → Counterparty advances USDC             [PACKET]
  → Settle: wire | Credit V2 borrowTo | desk
  → KingVault / Landing (ops + expand)     [ROUTE]
  → Fees (BRETT/RSS/new) → passive yield
  → Loop external pairs → more depth
```

---

## Packets

| Doc | Role |
|-----|------|
| `CDP-LIVE.md` | Step 1 proof |
| `ZK-RESERVES-LIVE.md` · `ATOMIC-COLD-OR-REVERT.md` | Steps 2–4 |
| `SECURE-700K-TOTAL.md` | Counterparty ask |
| `SPOILS-OF-WAR.md` | Desk/bond/dutch/fees |
| `BEFORE-COLD-SEA.md` | Pre-settle checklist |

**King one-liner:** Mint · prove · fill · vault · fee · loop — RSS stays sovereign.
