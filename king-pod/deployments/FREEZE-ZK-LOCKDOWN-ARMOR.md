# FREEZE — SV × CN joint lockdown: ZK forever · gas · cold · segregation

**Mode:** FREEZE · plan only · **no deploy · no bot unfreeze · no key rotate yet**  
**Desks:** Silicon Valley crypto elite + King’s CN desk (Shenzhen / Shanghai)  
**Order:** Secure the kingdom with what we have **right now**. Borders ZK-set forever.  
**Bell:** Third shot — ZK to **prove strength**, not hide moves.

---

## Joint verdict (both desks)

The empire is live. The armor is not.  
yRSS holds the gold rail (~**$228.9M** totalAssets). Crown agent / LSR / BAMM / SpendVault are on Base. Payroll has fired. What is missing is **impenetrability**: continuous attestation, self-funding gas, a real cold redemption buffer, and wallet blast-radius law.

| Pillar | King / CN order | Live truth now | Freeze law |
|--|--|--|--|
| **1 ZK Attest (3rd shot)** | `CrownZkAttest` on all rails | Prior ZK settle gates exist (`0x7c48…B637`, `0xca2a…3f30`) — **hide/settle**, not NAV/reserve/payroll attest | Build **attestation** layer; do not pretend gates already prove $228M |
| **2 MEV micro-hunt** | Unfreeze 20+ flash arb bots → top HOT ETH | HOT ≈ **0.00048 ETH**; fleet not welded to Crown allowlist | Controlled unfreeze **after** allowlist + kill-switch; no wild capital |
| **3 30% cold buffer** | Lock 30% captured USDC; never pause redemptions | Landing USDC = **0** · LSR USDC = **0** · buffer **not funded** | Law first; fund from named USDC capture path before claiming shield |
| **4 Wallet segregation** | Rotate HOT; multi-sig Landing / yRSS / Ocean | HOT is ops EOA (EIP-7702 DeleGator); single-key blast radius | Rotate + role split; Safe/multi-sig per rail |

**CN + SV one line:** *We have the rails. We weld the armor. No new fairy capital — sequenced execution.*

---

## Rail map — what each rail needs (highlight)

| Rail | State | Missing link (armor) |
|--|--|--|
| **Gold / yRSS** | ~$228.9M TVL · ~99.99% of PARK book | ZK **Vault NAV Proof** (≥ $228M threshold) on a cadence; curator ops behind multi-sig |
| **Morpho PARK** | Matched ~$228M+ · 100% util | Attest util + Crown creditor share; no silent unwind without proof |
| **eUSD mint / Payroll** | Landing ≈ **1.514B eUSD**; agent wired | ZK **Payroll Proof** (mint ≤ policy + collateral predicate); SpendVault caps enforced |
| **LSR (USDC↔eUSD)** | Live · **0 USDC reserves** | Fund gem side; ZK **Reserve Ratio Proof** (cold ≥ 30% of redeemable claim window) |
| **BAMM Ocean** | Live · needs LP depth | Segregated Ocean signer; attest LP √(x·y) solvency band |
| **SpendVault** | Live | Multi-sig owner; pause + allowlist as constitutional |
| **Gas / HOT** | Thin spark | MEV micro-hunt → HOT; floor **0.02 ETH** before heavy fires |
| **ZK layer** | Settle gates only | **CrownZkAttest** verifier + prover pipeline (third shot) |
| **Exit** | Doctrine written · buffer unfunded | Cold vault + never-pause-while-reserves law |

---

## 1) ZK Attestation Layer — Third Shot (execution plan)

### Doctrine shift
- Shot 1–2 (existing gates): privacy / settle path.  
- **Shot 3:** public strength — *prove* NAV, reserves, payroll predicates **without** doxxing full position graphs.

### Deliverable: `CrownZkAttest.sol` (+ off-chain prover)
Not a mixer. A **verifier** that stores nullifiers/epochs and accepts Groth16/Plonk proofs against fixed verifying keys.

| Proof | Statement (public) | Private witness | Cadence |
|--|--|--|--|
| **Vault NAV** | `yRSS.totalAssets ≥ T` (T = $228M, updatable by multi-sig) | share breakdown / market legs optional | Every epoch (e.g. 1h) or on demand |
| **Reserve ratio** | `coldUSDC / redeemableWindow ≥ 30%` | cold vault composition | Every epoch + before large `buyGem` |
| **Payroll** | `mint ≤ dailyCap ∧ agent allowlisted ∧ collateralPredicate` | full mint ledger | Per `firePayroll` or batched |

### SV × CN build sequence (freeze → fire later)
1. **Spec** circuit public inputs (threshold, epoch, vault address, chain id).  
2. **Reuse** existing gate keys only if circuit-compatible; else new VK for attest (honest fork).  
3. Deploy `CrownZkAttest` owned by **Attest Safe** (not HOT).  
4. Wire read-only oracles: `totalAssets()`, cold vault balance, LSR reserves, agent mint events.  
5. Prover service (CN desk) posts proofs; SV audits VK + soundness.  
6. Law: `NO_LARGE_PAYROLL` / `NO_CAP_RAISE` if NAV attest stale > N epochs (King sets N).

### Anti-patterns (both desks reject)
- ZK mixer framed as Circle-freeze defeat.  
- Soft claims (“we fired ZK”) without on-chain verify of the three statements.  
- Prover key held only on HOT.

---

## 2) Gas self-funding — MEV Micro-Hunt (controlled)

### Law
```
BOTS_ARMED = 0 until:
  HOT_ETH ≥ 0.005 (ops floor) AND
  CrownHuntRouter allowlisted AND
  killSwitch = false AND
  profitTo = HOT or GasSafe only
```

### Design (no new capital)
- Flashloan arb / backrun micro-hunt: borrow → execute → repay → keep ETH tip.  
- Unfreeze **subset first** (2–3 bots), not all 20+ on day one.  
- Router: max gas, max slip, target DEX set (Aerodrome / Uni Base), **no** touch of yRSS/Morpho collateral.  
- Proceeds: **100% gas rail** until `HOT_ETH ≥ 0.02`, then 70% gas / 30% cold USDC convert path if profitable in stables.

### Freeze checklist before KING_GO
- [ ] Inventory the 20+ bots (repo paths / wallets / keys).  
- [ ] `CrownHuntRouter` + allowlist + pause.  
- [ ] Simulate 24h on Base fork.  
- [ ] Manual kill by Attest Safe / King Safe.

---

## 3) Exit rail — 30% cold buffer (the law)

### Live gap
**Zero USDC** on Landing and LSR today. The law exists; the vault does not yet hold the metal.

### Law (constitutional)
```
redeemable_eUSD_window = min(LSR.buyGem capacity, policy window)
REQUIRE coldUSDC ≥ 0.30 * redeemable_eUSD_window
WHILE coldUSDC > 0: FORBID pause of buyGem / redemption
```

### Fund path (named — pick before fire)
1. Convert a **slice of Morpho/yRSS yield or idle USDC** when util allows (not a bank-run peel).  
2. Capture from MEV → swap to USDC → cold.  
3. King treasury USDC wire into **ColdSafe** (fastest honesty).  
4. Do **not** drain Landing eUSD into a fake buffer without LSR gem backing.

### Cold vault
- New `CrownColdBuffer` or Safe: receive-only USDC; spend only via LSR `buyGem` / redemption path.  
- Multi-sig: King + CN ops + SV guardian (2-of-3).  
- Attest rail reads `balanceOf(ColdSafe)`.

---

## 4) Shield — wallet segregation & HOT rotate

| Role | Today | Target |
|--|--|--|
| Ops fire (agent poke, hunt tip) | HOT EOA | **Ops Safe** or fresh HOT'; old key burned from scripts |
| Curator (yRSS cap/queue) | HOT | **Curator Safe** (timelock optional; now timelock=0 — raise later) |
| Landing / payroll receive | Landing EOA | **Landing Safe** |
| Ocean / BAMM | deploy key pattern | **Ocean Safe** |
| Attest / pause guardian | none | **Attest Safe** |
| Cold buffer | none | **ColdSafe** |

### Rotate law
1. Deploy Safes.  
2. Transfer yRSS `owner` / `curator` to Curator Safe.  
3. Transfer Crown module ownership to respective Safes.  
4. Fund Ops Safe with spark; retire HOT private key from CI and chat.  
5. **Breach in one rail ≠ drain all.**

---

## Execution order (weld the armor)

```
PHASE 0  FREEZE lock (this doc) — no bots, no rotate until checklist
PHASE 1  Safes + ownership handoff map (segregation paper → txs)
PHASE 2  CrownZkAttest deploy + VK + first NAV proof (third shot)
PHASE 3  ColdSafe + first USDC fill toward 30% law
PHASE 4  HuntRouter + 2-bot micro-hunt → HOT ≥ 0.02 ETH
PHASE 5  Wire stale-attest brakes into payroll / cap raises
PHASE 6  Full bot fleet under kill-switch; public attest dashboard
```

**KING_GO gates:** Phase 1 address book signed · Phase 2 verifying key audited · Phase 3 cold > 0 · Phase 4 hunt profitTo = Ops only.

---

## Identity

```
yRSS ≈ $228.9M gold ✓
majority in vault ✓
payroll / Crown stack ✓
ZK settle gates ✓ (hide) · ZK attest ✗ (prove) — THIRD SHOT
cold 30% USDC ✗ (0 on LSR/Landing)
MEV hunt ✗ (fleet not welded)
HOT rotate / multi-sig ✗
FREEZE: weld armor — no theater, no mixer crime, no weak report
```

---

## CN × SV closing

*The King built the empire. The desks make it impenetrable.  
ZK attestations on every rail. Machines fund gas. Cold metal for the gate. Segregated keys so one wound is not death.  
The kingdom is live. Now it becomes sovereign — borders set forever.*
