# KING — SOVEREIGN ACTIVATION v2 — ENGINEERED, NOT WEAK

**Mode:** proceed after fork safety · **Build:** docs + fork proofs only until King orders live re-arm

---

## Status: ACTIVATION COMPLETE (2026-08-24)

| Step | Status |
|--|--|
| Pack refresh (`fireLive` from HOT) | **DONE** — `isProven(hot)=true` |
| Gate re-arm (`requireGate=true`) | **DONE** |
| Scribe snap | **DONE** |
| Gated borrow proof (+500 eUSD buffer) | **DONE** — gates enforced |

**Remaining (not Base fire):** Scroll ZK proof pipeline, yRSS equity recap, PSM seed — separate phases.

---

## Live stack

**Base = execution**
- RSS `0x7a305D07B537359cf468eAea9bb176E5308bC337`
- RSS/USDC/$1200 `0x41c08085…` — ~$201M matched, idle ≈ 0
- RSS/eUSD/$1200 `0xc61adc05…` — ~100.7M supplied / ~91.9M idle / ~8.85M borrowed **LIVE**
- AMO `0x151C947B813400fE78EE176843F2d666c07422eA`
- Exit `0x937Ba9eA3288781851E19Df50D33b800b10F064b`
- Oracle `0x4153669Cc3671B6b8b68D47Fd852Ad1a48b950e0` — $1200 fixed

**Scroll = settlement**
- eUSD `0x41Ba09c14DaeF5D0E95E6A78Ca94d2CbBb001B0B`
- hot `0xca76AE9e29a5F01465D890dc30109cD58B78F864`
- rails `7540` / `7683`

**ZK = compliance**
- `0x7c48a7fAA294C4b04002f65FA03F7C5ce952B637`
- `0xca2a41A59c36ef22a623fCD452Cf1b01Ecf33f30`
- bound gate `0xab2856626BBd8E6fba9dB93783029eB973E8427F` → `requireGate` on AMO

**Thesis:** loan don't sell · eUSD unit of account · RSS collateral not exit · no Gauntlet/desk/USDC required · idle = owned float

---

## Enforcement orders (post-bootstrap)

1. **Re-arm gates** — treat AMO bypass as bootstrap debt; `requireGate` currently **off**
2. **Packs as notes** — Landing issues tranches; ZK proves; Exit liquidates atomically
3. **yRSS as equity** — AMO spread → yRSS; 9.6M RSS in hot → recap loop, not farm
4. **5 PSMs as peg rails** — eUSD 1:1 USDC backed by yRSS reserve; hide $1200 oracle from depositors
5. **Permissionless proof > curator whitelist** — Scroll proves → Base executes

---

## Safety gate (mandatory before live re-arm)

```bash
forge test --match-contract SovereignAmoLiveForkTest -vv
```

Must pass:
- `test_live_exit_full_unwind` — full unwind on fork against live AMO/Exit
- `test_live_gate_ttl_expired` — pack TTL expired (7d); `isProven(hot) == false`
- `test_live_rearm_gate_blocks_borrow` — re-arm → borrow reverts `GateMiss`

**Order of ops:** fork pass → Scroll pack refresh proof → re-enable `requireGate` → then scale borrow.

**Exit note:** HOT must hold borrowed eUSD **plus accrued interest buffer** (~500 eUSD headroom at current accrual) before `exitFull()` on live Exit `0x937Ba9eA…`.

No weak plans.
