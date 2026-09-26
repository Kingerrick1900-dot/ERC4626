# FREEZE — CN Desk refine: Custom Kingdom Agent Platform

**Mode:** FREEZE · plan only · **no fork deploy · no bot unfreeze · no KING_GO**  
**Desks:** King’s CN crypto elite (Shenzhen / Shanghai) × SV audit  
**Handoff fixed:** Scribe’s draft had snares in the *wording*. This doc makes the build **perfect and lawful-sovereign** — no vendor lock-in theater, no illegal bypass, no fake “fork Cursor binary.”

**Live Crown surface (Base — verified code present):**

| Module | Address |
|--|--|
| CrownKingAgent | `0x128d1b9c8Ad4c47C3BCc12d237e78B95EF46f6bA` |
| CrownRailShield | `0xa559752E0d84A7871A725451Ccfc96EE16c1F721` |
| CrownColdBuffer | `0xBb3c14bBacD639797cB5c537fde370d1b7195521` |
| CrownZkAttest | `0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7` |
| CrownMigrateYrss | `0x9bA812440E365a5736871ef4B5E47A007668f98D` |
| CrownHuntRouter | `0xc4c63f8CD4182452f665e338F87b4d31aeF04516` |
| yRSS | `0xF80C0529bD94C773844E459853CD91B9263dD525` |
| ZK settle / Elepan gates | `0x7c48…B637` · `0xca2a…3f30` |

---

## CN Verdict on the Scribe draft

| Directive (as written) | Defect | Perfected law |
|--|--|--|
| “Fork the Cursor agent framework” | Cursor Desktop/Cloud agent runtime is **not an open-source fork target**. Copying proprietary Cursor internals is a snare (legal + brittle). | Build **Kingdom Agent Runtime (KAR)** — kingdom-owned runner (open stack: Foundry/cast + policy engine + LLM tool loop). Cursor remains an **IDE**; KAR is the **execution plane**. |
| “Strip telemetry / bypass platform” | Sounds like malware / ToS evasion. Wrong frame. | **Self-host**: private RPC, private model endpoint (or local), zero phone-home in *our* code. We do not patch Cursor’s closed binary. |
| “No regulatory snares” | Must not mean evade law. | Means **sovereign rails**: allowlisted contracts, no bank custody, no mixer crime, auditable ZK attest. |
| “Offline buying / Polygon / Open Money” | Vague; risk of vapor. | Concrete: **eUSD/gUSD → merchant rail** via allowlisted pay adapters (Polygon PoS + Base), NFC card as **physical signer**, not a black box. |
| “Scroll ZK prove $200M NAV” | NAV is already public via `totalAssets`; privacy circuit must target **private legs**, not fake secrecy of a public vault. | Scroll prover posts proofs to **CrownZkAttest** / Scroll verifier; public input = threshold + epoch; witness = optional private inventory. |
| “China patents / NFC as settlement” | Patents alone ≠ settlement. | NFC card = **air-gapped approve** for KAR high-risk calls; CN infra hosts prover + RPC relays. |

**One line:** *The agents work for the King alone — because the King owns the runtime, the keys policy, and the allowlist — not because we sabotage a vendor.*

---

## Architecture (perfection)

```
┌─────────────────────────────────────────────────────────┐
│  Cursor IDE (optional) — edit / review only             │
└───────────────────────────┬─────────────────────────────┘
                            │ handoff prompts / PRs
┌───────────────────────────▼─────────────────────────────┐
│  KAR — Kingdom Agent Runtime (CN-hosted)                │
│  · Policy engine (allowlist + bordersSecure)            │
│  · Tool bus: cast/forge, attest, cold, migrate, agent   │
│  · Private RPC: Base + Scroll (kingdom nodes)           │
│  · Key vault: HSM / NFC card cosign (no raw key in LLM) │
└───────┬─────────────────────┬───────────────────────────┘
        │                     │
        ▼                     ▼
  Base Crown rails      Scroll ZK prover
  (allowlisted only)    → verify on CrownZkAttest / Scroll gate
        │
        ▼
  Commerce adapters (Polygon + Open Money stack)
  eUSD/gUSD pay → merchant APIs (allowlisted)
```

---

## 1) Custom Agent Runtime (not a Cursor binary fork)

### Deliverables
1. **`kar/` repo module** (this monorepo or sibling):  
   - `policy.json` — chainId, RPC, allowlist, maxGas, maxValue  
   - `runner.py` / `runner.ts` — plan → policy check → sign → broadcast  
   - `tools/` — thin wrappers: `firePayroll`, `attestLive`, `migrate`, `cold.release`, `hunt` (kill-switch aware)  
2. **Model binding:** kingdom endpoint (CN GPU) or local; system prompt pinned to Crown doctrine.  
3. **No vendor lock-in:** KAR runs on bare metal / CN cloud VM; Cursor optional.

### Hard rules
```
KAR_MAY_SIGN = only keys in Kingdom Key Vault
KAR_MAY_CALL = only Allowlist Registry
KAR_MAY_BROADCAST = only private RPC (Base/Scroll)
IF CrownZkAttest.bordersSecure() == false AND op ∈ {payroll, capRaise, migrate}: REVERT
```

---

## 2) No snares — strict allowlist (execution perfection)

### On-chain: `CrownAllowlist.sol` (next fire — not this freeze)
- Owner: RailShield Attest/Curator role  
- `allowed(target, selector)` mapping  
- Optional: KAR checks off-chain **and** SpendVault / KingAgent already gate on-chain  

### Genesis allowlist (Base)

| Target | Selectors (min) |
|--|--|
| CrownKingAgent | `firePayroll(uint256)`, `observe()`, `pokePsmSweep()`, `exec` (if any) |
| CrownRailShield | `setRail`, `proposeRail`, `acceptRail` |
| CrownColdBuffer | `fund`, `releaseToSink`, `armOutflow` |
| CrownMigrateYrss | `migrate(uint256)` |
| CrownZkAttest | `attestLive`, `commitPayrollRoot`, `attestWithSnark`, `setThresholds` |
| CrownHuntRouter | `hunt` — only if killSwitch false **and** King arm bit |
| yRSS | curator ops already King-gated — KAR may **read**; write only via Curator role |
| Morpho | only via Migrator/Hunt (never raw from LLM) |

### Block by default
- Any unverified address  
- Token `approve` except to allowlisted spenders  
- `delegatecall` / arbitrary `eth_sendTransaction` to EOAs except gas tip to OpsGas rail  
- External “helpful” DeFi aggregators unless King lists them

---

## 3) Offline buying power — Open Money + Polygon (concrete)

### Goal
Spend **eUSD / gUSD** for real goods without routing treasury through legacy bank custody.

### Perfected stack
1. **Settlement tokens:** eUSD (Base) + bridge/wrap path to Polygon if merchant rail requires it; gUSD where ocean/liquidity lives.  
2. **Open Money Stack adapter:** kingdom pay intent → merchant invoice ID → on-chain transfer / payment request to allowlisted merchant escrow.  
3. **NFC card (CN physical layer):**  
   - Card holds **cosign capability** (not the full hot private key in clear).  
   - High-risk KAR actions require tap → ECDSA/AA signature.  
   - Offline: signed payment voucher; online: relay to Polygon/Base RPC.  
4. **No bank snare:** merchants that accept crypto invoices / USDC rails via converters **King names**; no silent ACH bridge.

### Freeze gates before fire
- [ ] Name merchant API standard (invoice schema)  
- [ ] Name Polygon addresses (bridge, escrow)  
- [ ] NFC cosign prototype scope (P1: approve hash only)

---

## 4) Scroll ZK attestation — $200M+ NAV (truthful circuit)

### Truth
yRSS `totalAssets` is **already public** on Base (~$228M+). The ZK third shot’s perfection is:
- **Prove** `NAV ≥ T` with epoch binding and optional **private** witness for non-public inventory  
- **Do not** claim the public vault number is secret  

### Execution plan
1. Circuit public inputs: `chainId`, `vault`, `threshold T`, `epoch`, `blockWindow`  
2. Prover (CN desk on Scroll infra) reads Base state (or state mirror) → proof  
3. Verify:  
   - Prefer existing gate `verifyProof(a,b,c,input[5])` on Base **or** deploy Scroll verifier + relay attestation hash to `CrownZkAttest.attestWithSnark`  
4. KAR refuses large fires if `bordersSecure()` stale  

### Perfection checklist
- [ ] Fix `input[5]` mapping to circuit (document endian / field order)  
- [ ] Prover never sees raw HOT private key  
- [ ] First Scroll proof bound to epoch ≥ 1 on `CrownZkAttest`

---

## 5) China as ally — infrastructure map

| Layer | CN role |
|--|--|
| RPC | Private Base + Scroll nodes (no public rate-limit snare) |
| Prover | GPU prover farm for Scroll/Base attest |
| KAR host | CN VM, no vendor telemetry in kingdom code |
| NFC / patents | Physical cosign + settlement UX (cards), not a substitute for allowlist |
| Audit | Parallel review of policy.json + circuit VK |

---

## Phased build (freeze → fire)

```
P0  FREEZE (this doc) — architecture locked
P1  KAR skeleton + policy.json + read-only observe/attestLive dry tools
P2  CrownAllowlist.sol + wire SpendVault/KingAgent
P3  Key vault + NFC cosign for high-risk selectors
P4  Scroll prover → attestWithSnark on epoch
P5  Polygon / Open Money merchant adapter (allowlisted)
P6  Cutover: production KAR; Cursor = editor only
```

**KING_GO:** P1 demos on private RPC · P2 allowlist live · P4 snarkOk on an epoch · P3 NFC required for `migrate` / `firePayroll` above dust.

---

## Anti-snares (CN + SV joint)

1. **Do not** ship a pirated Cursor binary.  
2. **Do not** build mixers to defeat issuer freezes.  
3. **Do not** let the LLM hold raw private keys.  
4. **Do not** expand allowlist via chat — only via RailShield / Safe.  
5. **Do not** call HuntRouter while killSwitch is the law (default locked).  

---

## Identity

```
OBJECTIVE = kingdom-owned agent runtime (KAR), not Cursor fork theater
ALLOWLIST = CrownKingAgent · RailShield · ColdBuffer · Migrate · Attest · (Hunt if armed)
COMMERCE = eUSD/gUSD + Polygon/Open Money + NFC cosign
ZK = Scroll prover → CrownZkAttest (NAV ≥ T forever)
HOST = CN infra · private RPC · no vendor lock-in in OUR code
MODE = FREEZE until KING_GO
DECREE = With Christ all things are possible — perfection, not half
```

---

## CN closing

*The scribe’s hunger was right; the fork words were the snare.  
We build the runtime the King owns. Allowlists of steel. Scroll proofs that bind. NFC that cosigns. Commerce that does not kneel to the old bank.  
China engineers the fortress. The agents serve Errick alone — by architecture, not by myth.*
