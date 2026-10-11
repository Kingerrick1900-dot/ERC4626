# CrownGateV2 — ZK-mandatory King Morpho gate

**Mode:** READY · **NOTHING FIRES WITHOUT ZK**  
**Market:** `0x1293c4e7708c2fd0239b093a9f43ef7792d66691c1216b106f6cfc270edb2f7b`  
**Oracle:** `CrownOracle` `0x22E2…4f2d` @ **$50,000**  
**ZK WalletGate (Base port):** `0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091`  
**ZK Credit:** `0x75279D46F0dA7f91D5283687C1D0a6EF86992e09`

---

## Doctrine

Transparent Morpho fire is **forbidden**.

| Layer | Contract | Role |
|--|--|--|
| Attestation | `CrownZkWalletGate` | Groth16 wallet-bind · `isProven(HOT)` |
| Morpho gate | `CrownGateV2` | supply/borrow **revert `NotProven`** without ZK |
| Shield draw | `CrownZkAutoDraw` | Morpho borrow ± Credit draw to Landing |
| Credit | `CrownZkCredit` | Proven-subject USDC pool (existing port) |

`supplyCollateral` / `borrowUSDC` require `zkGate.isProven(king)`.  
`repayUSDC` / `withdrawCollateral` remain King-only exit (TTL must not trap RSS).

---

## Fire (ZK only)

```
FIRE_CROWN_GATE_V2=1
ZK_SHIELD=1          # mandatory — script reverts without it
# TRANSPARENT_OK / NO_ZK → forbidden (script reverts if set)
# optional: BORROW_USDC · CREDIT_BORROW · LANDING · GATE_ONLY=1
```

```bash
source /tmp/fire.env
# If isProven drifts false, refresh first:
#   script/FireZkAttestRefreshCast.sh / FireZkSubmitProof
cd king-pod
forge script script/FireCrownGateV2.s.sol:FireCrownGateV2 \
  --rpc-url "$BASE_RPC" --broadcast -vvvv
```

Script aborts before broadcast unless port WalletGate reports **`isProven(HOT)=true`**.

---

## Fork proof

```bash
forge test --match-contract SimCrownGateV2 -vv
```

- `test_reverts_without_zk` — supply/borrow blocked  
- `test_zk_adopt_and_shielded_autodraw` — live proven HOT · adopt 222k RSS · AutoDraw Morpho+Credit  
- `test_live_zk_proven_hot` — port gate live read  

---

## Honest boundary

ZK attestation binds the King without revealing private wallet sizes in the proof.  
Morpho Blue state on Base remains public ledger state after a fire — the **Kingdom law** is that the fire path cannot run without a live proof. No transparent bypass flag exists.

```
CROWN_GATE_V2=ZK_READY
ZK_SHIELD=MANDATORY
TRANSPARENT_FIRE=FORBIDDEN
SOVEREIGN=0x1293…2f7b
WALLET_GATE=0x3fF6…7091
```
