# WELD — StarkSnarkBridge ↔ CrownZkAttest (ATTESTER_ROLE)

**Doctrine:** No deployment without the full quantum bind. ZK and quantum are the armor.  
**Failure fixed:** Legacy Attest `commitPayrollRoot` was `onlyOwner`. Bridge `bindToAttest` reverted `NotOwner`. Scaffold path that skipped bind is dead.

---

## Fix executed

| Step | Action | Result |
|--|--|--|
| 1 | Deploy Attest with `ATTESTER_ROLE` + `grantRole` | [`0xDFd6414e…354F`](https://basescan.org/address/0xDFd6414e8F699d7593803333116CF8C4d717354F) |
| 1b | Deploy Stark bridge wired to new Attest | [`0xE4cc983E…B8A1`](https://basescan.org/address/0xE4cc983E919374591cDe809E3Dc2D8aDa97cB8A1) |
| 1c | `grantRole(ATTESTER_ROLE, Stark)` | **true** |
| 2 | `commitStark` + `bindToAttest` | bound |
| 3 | Verify | below |
| 4 | Deploy Gate + Scoreboard **only after bind** | Gate A live · Gate B locked on Exit inventory |

Legacy Attest `0xe3Be…14E7` / Stark `0x0E88…2B07` remain historical (2035 path used HOT-direct `commitPayrollRoot` — not a bridge weld). **Armor surface is the new pair.**

---

## Verify (multicall)

| Read | Value |
|--|--|
| `CrownZkAttest.latestEpoch()` | **1** |
| `CrownZkAttest.latestProof()` | non-zero payload hash |
| `StarkSnarkBridge.isBound()` | **true** |
| `bordersSecure()` | **true** |
| `hasRole(ATTESTER_ROLE, Stark)` | **true** |

Script: `script/WeldStarkAttestBind.s.sol`  
Broadcast: `broadcast/WeldStarkAttestBind.s.sol/8453/run-latest.json`

---

## Gates (frozen until bind — now welded)

| Module | Address |
|--|--|
| **CrownUnbreakableGate** | [`0x4946D33b…A148`](https://basescan.org/address/0x4946D33b2539FE175F0CCceB42fBb0ED3dD0A148) |
| **CrownLoopScoreboard** | [`0x58C93C9F…d120`](https://basescan.org/address/0x58C93C9Fe9d3847addC52E433E445ae0dE78d120) |
| `armorBound` | **true** |
| Gate A (depth > $2M) | **true** · depth ≈ $3.1M |
| Gate B (exit > $500k) | **false** · Exit inventory $0 (honest) |

Every gate phase calls `requireBind()` → reverts `BindRequired` if Stark is not bound.

Prior scaffold gate `0x60d56fAD…902C` is **superseded** — no bind check.

---

## Code changes

- `CrownZkAttest`: `ATTESTER_ROLE`, `grantRole` / `revokeRole` / `hasRole`, `latestEpoch`, `latestProof`; `commitPayrollRoot` = owner **or** attester
- `CrownStarkSnarkBridge`: `isBound()` / `isBound(bytes32)`
- `CrownUnbreakableGate`: `requireBind()` on all phase entrypoints

```
WELD=stark-attest ✓
ATTEST=0xDFd6414e…354F epoch=1
STARK=0xE4cc983E…B8A1 isBound=true
GATE=0x4946D33b…A148 armorBound=true gateA=true gateB=false
NEXT=fund Exit >$500k → confirmExit → flywheel → armScale
```
