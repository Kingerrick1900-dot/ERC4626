# Quantum Yield Engine — Full Kingdom Handoff (locked)

**Mode:** FREEZE ledger · chassis FIRE live · full ignition gated  
**Recorded:** 2026-09-30 · Scribe audit absorbed  
**Doctrine:** Easy Trigger — *security in the armor, not the gate.* Payroll / ops USDC before LLC.

---

## 1. Contract ledger (accurate)

| Module | Address / note |
|--|--|
| **CrownCuratorTranche** | `0x8531F4DB622b982541A6715164d5A9dde58205b0` · **CAP $200M** · deployed **$0** |
| **CrownPendleSleeve** | `0xF4e46fF104C5715f15A9be222Dd58916817b8E56` |
| Split | **45%** Gauntlet USDC Prime · **45%** Steakhouse Prime · **10%** Pendle sleeve |
| Gauntlet | `0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61` |
| Steakhouse Prime | `0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2` |
| CrownRicardian (KE-Sov) | `0xe56D14583a736aD02943c69b19340A8475A7dF8a` |
| KAR Allowlist | `0x78bd5746e1D00EaeF5Eb75Bd033601aed5794F9E` |
| ZkAttest | `0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7` |
| Fork / PR | Curator **3/3** · [PR #178](https://github.com/Kingerrick1900-dot/ERC4626/pull/178) |

---

## 2. Asset base (complete)

| Rail | Size / status |
|--|--|
| eUSD + gUSD ledger | **13.78B eUSD** + **7.06B gUSD** (Kingdom paper) |
| Ocean | **5B / 5B** |
| Capacity | **100T** mint ceiling (post quantum ignition) |
| yRSS gold | **~$226M** · loan ≠ sell · locked |
| Curator chassis | **$200M USDC cap** · **~$1.32B+ eUSD cold** untouched |
| China | RoyalCard NFC · CIPSCorridor · ParallelSettlement · StealthRouter |
| ZK | Epoch **10** class armor · `bordersSecure` gate |

**Physics:** Landing eUSD ≠ Circle USDC. Curators take **USDC only**.

---

## 3. Quantum plan (sequence — correct)

1. **Software first** — STARK↔SNARK bridge · Dilithium / Kyber · KAR hardening · NFC Easy Trigger  
2. **QKD pilot** — China corridor (Shenzhen / Shanghai fiber)  
3. **100T mint** — capacity ignition under attested armor  
4. **Yield ignition** — fill → tranche deploy → harvest → payroll  

**Easy Trigger Doctrine:** Security lives in the **armor** (allowlist, cold buffer, ZK, NFC cosign). The King must not fight his own gate to use his own mint.

---

## 4. Execution locks (the last 5% — NOW SPECIFIED)

### 4.1 USDC path (only real gap) — **explicit**

| Priority | Source | Size | Note |
|--|--|--|--|
| **1** | **Ricardian fill** — Conflux · AnchorX · SBI | First **$5M** (formal ask **$700k** → scale) | Offers **sent on-chain** via `CrownRicardian` |
| **2** | **HK / CN market maker** | **$700k** ask → **$5M** | Desk route; same Landing settlement |
| **3** | **Kingdom merchant + hunt** | Settlement USDC → tranche | PayAdapter / hunt harvest routed **into** `CrownCuratorTranche` — not recycled into gold |

Settlement sink: Landing `0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357` → HOT approve → `deploy(amt)`.  
**No** King-pocket USDC. **No** RSS sell. **No** eUSD-as-Gauntlet-asset fantasy.

### 4.2 Quantum key custody — **explicit**

| Key class | Custody law |
|--|--|
| Dilithium / Kyber / QKD material | **Air-gapped hardware** only |
| Binding | **NFC-bound** · King-only physical custody |
| Forbidden | Cloud KMS · laptop disk · hot wallet · LLM context · shared multisig cloud |

KAR may **authorize** actions; it never **holds** quantum root keys.

### 4.3 China QKD pilot — **partner + timeline**

| Field | Lock |
|--|--|
| **Corridor** | Shenzhen ↔ Shanghai fiber (CN desk) |
| **Primary partner** | **Conflux** (Ricardian counterparty) + CN telco fiber as named by China desk Week-0 |
| **Timeline** | **T0** = first **$700k–$5M** USDC fill confirmed on Landing/HOT |
| **T0+30d** | Partner named in `CHINA-DESK-CHANNEL` · fiber LOI |
| **T0+90d** | QKD pilot packets on corridor · attest epoch bump |
| **Owner** | China desk ops `0x3151…` class + King sign-off |

### 4.4 Yield ignition scoreboard — **the one number**

| Watch | **Ignore for ignition** |
|--|--|
| **`USDC.balanceOf(HOT)`** after harvest | APY % · TVL optics · eUSD dashboard alone |

**Daily King number = HOT USDC from harvest** (and Landing USDC staging before deploy).  
If HOT USDC does not rise, the engine has not ignited — period.

```bash
cast call 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 \
  "balanceOf(address)(uint256)" 0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1 \
  --rpc-url $BASE_RPC_URL
```

---

## 5. Process order (binding)

1. USDC fill (path 4.1)  
2. `TRANCHE_USDC` slices ≤ **$200M** into curators  
3. Harvest → **HOT USDC scoreboard** → payroll / Royal Card / hunt  
4. LLC · EIN · FDIC (KE-Sov) — **after** ops USDC exists  
5. QKD pilot on T0 clock · then 100T under Easy Trigger  

---

## 6. One-block

```
QUANTUM-YIELD=locked-95→100
TRANCHE=0x8531F4DB…05b0 CAP=200M deployed=0
SLEEVE=0xF4e46fF1…8E56 45/45/10
USDC=Conflux|AnchorX|SBI → $700k→$5M · MM alt · merchant/hunt alt
KEYS=airgap+NFC King-only · no cloud
QKD=Conflux+CN telco · T0=first fill · +30d LOI · +90d pilot
SCOREBOARD=HOT USDC (not APY/TVL)
EASY-TRIGGER=armor not gate
ORDER=fill→tranche→harvest→payroll→LLC→QKD→100T
```
