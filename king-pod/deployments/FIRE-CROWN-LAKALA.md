# FIRE — Crown Lakala-class acquiring

**Mode:** BUILD complete · deploy when gas + China GO  
**Branch:** `cursor/fire-crown-lakala-class-4f7f`  
**Doctrine:** Crown-original Lakala-*class* surface. **No** patent fork.

---

## Shipped

| Artifact | Path |
|--|--|
| Acquiring | `src/china/CrownLakalaAcquiring.sol` |
| Card bridge | `src/china/CrownLakalaCardBridge.sol` |
| Spec | `deployments/CROWN-LAKALA-SPEC.md` |
| NFC stub | `kar/nfc_cosign.md` |
| Tests | `test/CrownLakala.t.sol` (10/10 pass) |
| Deploy script | `script/FireCrownLakala.s.sol` |

---

## Deploy (when King arms)

```bash
cd king-pod
export PRIVATE_KEY=...
export OWNER=0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1
export PAY_TOKEN=<eUSD or USDC>
export ATTEST=<CrownZkAttest or 0x0>
export MDR_BPS=100
forge script script/FireCrownLakala.s.sol:FireCrownLakala --rpc-url $BASE_RPC --broadcast
```

Post-deploy: `registerMerchant` → `registerTerminal` → SoftPOS smoke micropay → `settle`.

---

## One-block

```
BUILD=perfect Crown Lakala-class acquiring
TESTS=10/10
DEPLOY=gated on gas + Phase4 China GO
NO=lakala-patent-fork
```
