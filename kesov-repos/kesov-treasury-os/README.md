# KESOV Treasury OS

Control plane for Kingdom treasury: Accounting → Policy → Risk → Intent → Execution.  
Bots submit **Intents only**. Sentinel **pauses** new Intents; unwinds need King’s signature.

## Corrected flaws (locked)

| Flaw | Fix |
|------|-----|
| Risk Controller merged with Policy | Policy = static rules; Risk = real-time Intent evaluator |
| `forceDeallocate` permissionless | Sentinel watches non-King callers; penalty non-zero on Vault V2 |
| Fixed $1 RSS / kUSD | Tag `internal-synthetic` — never blend into external solvency |
| Circular kUSD→RSS | `max_circular_exposure` in Policy |
| Intent Queue underspecified | Schema + 3 retries → dead-letter |
| Sentinel oracle source | Oracle Manager first-class |
| Bot fleet direct vault access | Intents only |
| No kill switch | Sentinel pause-only; unwind = King sig |

## Architecture

```
KING → HIGH TREASURY → PRIVATE META VAULT (Morpho Vault V2)
   → Adapters (Morpho / Aave / Internal CDP)
   → Accounting → Policy Engine → Risk Controller
   → Intent Queue → Execution Engine → Base
Oracle Manager + Sentinel + Monitoring
```

## Build order

1. **Phase 1 (this package):** Accounting + Oracle Manager (read-only) + dashboard :4000  
2. Phase 2: Policy Engine + Risk Controller (unit-tested)  
3. Phase 3: Intent Queue + Strategy + Execution Engine  
4. Phase 4: Sentinel live, shadow Risk, migrate bots to Intents  

## Pre-build checklist (status)

| Item | Status |
|------|--------|
| Confirm High Treasury Vault is V2 | **YES** — VaultV2 `0xB96BcfFB…A7b9` (yRSS `0xF80C…` is MetaMorpho V1 curator vault — separate) |
| `forceDeallocatePenalty` non-zero | **YES** — `1e16` (1%) on adapter `0x3088de5b…EE8c` |
| Test `forceDeallocate` tx + hash | **PENDING King green light** (no live fire) |
| Tag RSS/kUSD `internal-synthetic` | **YES** — Accounting Phase 1 |

## Run

```bash
cd kesov-repos/kesov-treasury-os
npm test                  # Phase 2 Policy + Risk + Sentinel + Intent Queue
npm run checklist         # Pre-build checklist (read-only)
npm run snapshot          # Accounting + Oracle JSON
npm run dashboard         # http://0.0.0.0:4000
```

Env: `BASE_RPC` / `RPC_URL` / `RPC` (default `https://mainnet.base.org`).

## Package layout

```
policy/default.json          Policy Engine static rules
src/accounting/layer.js      Accounting Layer (Phase 1)
src/oracle/manager.js        Oracle Manager (Phase 1)
src/policy/engine.js         Policy Engine (Phase 2)
src/risk/controller.js       Risk Controller (Phase 2)
src/intent/queue.js          Intent Queue schema + retries
src/sentinel/rules.js        Pause-only kill switch rules
src/adapters/index.js        Market adapter stubs
src/dashboard/server.js      Monitoring panel :4000
test/phase2.test.js          Unit tests (no RPC)
```

## Doctrine locks

- Policy Engine ≠ Risk Controller
- RSS / kUSD = `internal-synthetic` @ $1.00 — never blend into `externalNetUsd`
- `max_circular_exposure` default `0` (no kUSD→RSS solvency inflation)
- Sentinel pauses **new** Intents only; unwinds need `kingSigned`
- No live `forceDeallocate` test tx without King green light
