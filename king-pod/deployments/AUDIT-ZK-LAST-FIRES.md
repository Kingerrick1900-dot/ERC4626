# AUDIT — ZK shield on Falcon / Spoil / Landing fires

**Law:** `ZK_SHIELD=1` · `bordersSecure` · WalletGate `isProven` · quantum protection  
**Verdict:** Last fires were **not fully shielded**. Hardened going forward.

---

## What happened

| Fire | Tx era | `ZK_SHIELD` env | `bordersSecure` | `isProven(signer)` | `isProven(Safe)` |
|--|--|--|--|--|--|
| FireSpoilEusdRail (~301M) | live | **NO** | not checked | **NO** (HOT was/became STALE) | not checked |
| FireFalconStack | live | YES (env only) | not checked | **NO** | not checked |
| FireFalconKingSign | live | YES (env only) | not checked | **NO** | not checked |
| FireLandingEusdRail (~1.32B) | live | **NO** | not checked | **NO** (Landing never proven) | not checked |

Live WalletGate at audit:

| Subject | `isProven` | Note |
|--|--|--|
| HOT | **false** | `STALE_VALID` — TTL 7d expired |
| Safe | **true** | King custody OK |
| Landing | **false** | never attested |

Morpho supplies cannot be rewritten. Economic state (idle on rail) stands. **Process breach** is the finding.

---

## Fix (law restored)

1. `script/lib/ZkShieldLaw.sol` — shared require: env + borders + proven subject + proven Safe  
2. Patched: `FireSpoilEusdRail` · `FireLandingEusdRail` · `FireFalconStack` · `FireFalconKingSign`  
3. `FireZkWalletRefresh` — re-submit HOT wallet-bind proof to clear STALE  
4. Landing fires: `requireKingCustody` — Safe must be proven; Landing proven unless `KING_CUSTODY_OK=1`

```bash
# Refresh HOT attest (clears STALE)
FIRE_ZK_WALLET_REFRESH=1 ZK_SHIELD=1 \
  forge script script/FireZkWalletRefresh.s.sol:FireZkWalletRefresh \
  --rpc-url "$BASE_RPC" --broadcast --with-gas-price 5000000

# Optional: refresh borders ×3
bash script/FireZkAttestRefreshCast.sh
```

---

## Going forward

No fire broadcasts without:

```
ZK_SHIELD=1
bordersSecure() == true
isProven(signer) == true   # or KING_CUSTODY_OK=1 with isProven(Safe)
isProven(Safe) == true
```

## Remediation live

| Action | Result |
|--|--|
| HOT WalletGate refresh | [`0xeb1bc32b…1740`](https://basescan.org/tx/0xeb1bc32b2d011b7860c48680ee6c06355ce4ce42cfcb49f64e2f5e20c78a1740) · `isProven(HOT)=true` |
| Base `attestLive` | [`0x15eb1c88…2b5e`](https://basescan.org/tx/0x15eb1c88a15ca6900b957be69bd1441270086c68415919ed26079b8a8a392b5e) · `bordersSecure=true` · epoch 17 |
| Safe | still `isProven=true` |
| Landing | still unproven — needs wallet-bind proof before subject-strict fires |

```
AUDIT=ZK_GAP_ON_SPOIL_LANDING_FALCON
FIX=ZkShieldLaw+WalletRefresh_LIVE
HOT_PROVEN=true
SAFE_PROVEN=true
BORDERS=true
NEXT=NIGERIA_UNDER_FULL_ZK_LAW
```
