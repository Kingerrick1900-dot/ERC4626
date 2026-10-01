# FIRE — Kingdom Agent Runtime (KAR) platform

**Mode:** FIRE · executed on Base  
**Doctrine:** Agents serve the King alone — by allowlist architecture, not vendor myth.  
**Result:** On-chain allowlist + pay adapter live · borders refreshed · KAR runner shipped.

---

## Live addresses

| Module | Address |
|--|--|
| **CrownAllowlist** | `0x78bd5746e1D00EaeF5Eb75Bd033601aed5794F9E` |
| **CrownPayAdapter** | `0xA6D5C5257aCA0028D98a2f2244792Ba68f09f3B1` |
| CrownZkAttest (epoch **2**) | `0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7` |
| CrownRailShield | `0xA559752E0d84A7871A725451Ccfc96EE16c1F721` |

`bordersSecure() = true` · `firePayroll` **allowed** · `hunt(...)` body **blocked** (kill law)

---

## What fired

1. Deployed **CrownAllowlist** — default deny; genesis selectors for Agent / Shield / Cold / Migrate / Attest / Pay; Hunt only `setKillSwitch`.  
2. Deployed **CrownPayAdapter** — eUSD merchant rail; Landing listed as first merchant sink.  
3. Bound allowlist → Attest; `requireBorders = true`.  
4. Refreshed **attestLive** → epoch 2 (borders were stale).  
5. Shipped **`kar/`** runtime: `policy.json`, `runner.py`, NFC cosign stub, README.

Broadcast: `broadcast/FireKarPlatform.s.sol/8453/run-latest.json`

---

## KAR usage

```bash
python3 kar/runner.py status
python3 kar/runner.py check --target 0x128d1b9c8Ad4c47C3BCc12d237e78B95EF46f6bA --sig 'firePayroll(uint256)'
python3 kar/runner.py attest --fire
```

---

## Still above the line (next)

- NFC hardware cosign (stub documented)  
- Scroll prover → `attestWithSnark`  
- Real merchant allowlist beyond Landing  
- Multi-sig ownership transfer of Allowlist / PayAdapter  

---

## Identity

```
KAR ✓  Allowlist ✓  PayAdapter ✓  borders epoch2 ✓  hunt body ✗ (by law)
Cursor = IDE only · Kingdom owns execution
```
