# INBOUND MEMO — Signed LP · Cover for King's Combined Plan

**To:** Counterparty / LP desk (signed settlement)  
**From:** Kingdom Treasury · King Errick governance  
**Re:** USDC settlement to HOT for ZK-attested `fireWithCover`  
**Record:** PR #195 · `HANDOFF-BUILDER-COVER.md`

---

## Purpose

Land **≥ $2,000,000 USDC** on HOT (`0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1`) to trigger:

- **Borrow #2 Engine** $1M → Steak/Gauntlet via `CrownZkYieldLadder`
- **Borrow #1 Reserve** $1M → HOT payroll buffer

Execution: `CrownKingsCombinedFire.fireWithCover()` with `ZK_SHIELD=1` and `isProven(HOT)`.

---

## Settlement terms (template)

| Field | Value |
|--|--|
| Asset | USDC (Base) `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| Minimum amount | **2,000,000 USDC** (6 decimals) |
| Beneficiary | HOT `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| Chain | Base · chainId **8453** |
| Use of funds | Kingdom Combined cover fire only · no rehypothecation by counterparty |

---

## Counterparty attestations (required)

1. **Signed memo** (this document or annex) with amount, date, and settlement tx hash.  
2. **LP proof:** on-chain transfer or atomic swap receipt crediting HOT.  
3. **No classical-only rail** for Kingdom fire — settlement must not bypass WalletGate doctrine.  
4. Kingdom fires only after `isProven(HOT)` remains true on WalletGate `0x3fF6…7091`.

---

## Kingdom execution (after USDC lands)

Builder / King ops:

```bash
cd king-pod
export FIRE_KINGS_COMBINED=1 ZK_SHIELD=1 MODE=cover
# HOT_KEY signs; HOT must approve CombinedFire for USDC
forge script script/FireKingsCombined.s.sol:FireKingsCombined \
  --rpc-url "$BASE_RPC_URL" --broadcast --slow --private-key "$HOT_KEY"
```

Existing CombinedFire: `0x37C9b6f79cA311B40083363Eb231E62B980Fa646` (or redeploy per script if policy requires fresh operator wiring).

---

## What Kingdom does **not** accept

- Transparent fire (`TRANSPARENT_OK` / `NO_ZK`)  
- Third-party draw without `isProven()`  
- Sovereign oracle retargeting on cbBTC / external Morpho books  
- Stub flash or zero-collateral idle taps (Path 2 — **paused**)

---

## Contact block (fill at sign)

| | |
|--|--|
| Kingdom signatory | _________________________ |
| Counterparty signatory | _________________________ |
| Amount USDC | _________________________ |
| Settlement tx (Base) | _________________________ |
| Date (UTC) | _________________________ |

```
MEMO=SIGNED_LP_COVER
MIN_USDC=2000000e6
HOT=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
FIRE=0x37C9b6f79cA311B40083363Eb231E62B980Fa646
ZK_SHIELD=1
```
