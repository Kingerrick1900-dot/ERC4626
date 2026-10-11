# PROOF SET B — AMO 6 Green (on-chain)

**Mode:** PROOF · live reads + broadcast txs · **not an assertion**  
**Chain reads:** Base block **52194988** (armor) · Poly **94982799** · Scroll **35280083**  
**Law:** Engineering gated until this set is accepted. Assertions are not armor.

---

## 1) CircuitBreaker — deploy tx + address

| Field | Full value |
|--|--|
| **Address** | `0xd92482bb8a4Ac2F6B80cd1583D2b7AcB630759A8` |
| **Deploy tx** | `0x5ad54e0534153c7229aa791f79b25eee0c78bf2e090e47e45d8cd70f4c5920d2` |
| **Deploy block** | **52143520** · status **1** (success) |
| Broadcast | `broadcast/DeployAmo6Armor.s.sol/8453/run-latest.json` · CREATE `CrownCircuitBreaker` |

Live @ Base **52194988**:

| Call | Raw return |
|--|--|
| `armed()` | **`true`** |
| `tripped()` | **`false`** |
| `amoCount()` | **`4`** |
| `yRssBaseline()` | `255873051242331` |

First AMO register (PauseStub):

| Step | Tx |
|--|--|
| PauseStub create | `0x5074bec9bbcc6482b8b871bd658f387105f4b09b456bc4b9f0628df453c33a08` → `0xBbA40146e15EFE9350b41d99BD067630135c683E` |
| `registerAMO` | `0x982eb5788e9d4ef7e021bf00ed49e5e99a14997ef63068681fb95bfe3e5e3ece` |

---

## 2) minBufferBps = 3000 — setting tx

| Field | Full value |
|--|--|
| **ColdBuffer** | `0xBb3c14bBacD639797cB5c537fde370d1b7195521` |
| **setMinBufferBps(3000) tx** | `0x4e626ef50bc939d1e31caec215d911a6c84e1bebb9997f9b9cfc53a33b275963` |
| **Tx block** | **52143519** · status **1** |

Live @ Base **52194988**:

| Call | Raw return |
|--|--|
| `minBufferBps()` | **`3000`** |

---

## 3) MintGate — deploy tx + live `canMint() == false`

| Field | Full value |
|--|--|
| **Address** | `0xf2a6cE82E89C347637e173Dd892385A118048982` |
| **Deploy tx** | `0x159f6a82afb99796ee9228f3b1343c8880423603d1383894605831db0ac17fac` |
| **Deploy block** | **52143521** · status **1** |
| Broadcast | `broadcast/DeployAmo6Armor.s.sol/8453/run-latest.json` · CREATE `MintGate` |

Live @ Base **52194988**:

| Call | Raw return |
|--|--|
| `canMint()` | **`false`** |
| `unlocked()` | **`0`** |

---

## 4) bordersSecure = true — Base · Polygon · Scroll

| Chain | CrownZkAttest (full) | Block | `bordersSecure()` | `epoch()` |
|--|--|--:|--|--:|
| **Base** `8453` | `0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7` | **52194988** | **`true`** | **16** |
| **Polygon** `137` | `0x00cAe93dd7F8D3331fe697D8B636B550aD6D7211` | **94982799** | **`true`** | **8** |
| **Scroll** `534352` | `0x2ab17e3c00D783F58B106De2fB1723b4915Da257` | **35280083** | **`true`** | **10** |

**Statement:** All three chains listed above were **armed and read live** in this proof session. No chain was skipped.

Attest fire txs (prior, recorded in `FIRE-COMPLETE.md`):

| Chain | Attest tx |
|--|--|
| Base | `0xc78426fef6da5f7df6c25af80291f1aa879f786cdabb2cf62856e9fe38f76e03` |
| Polygon | `0xfddd5efb5ccaacb1414c04200aebd946a53486f63d3ff4f095fe589e36d419b6` |
| Scroll | `0x673a76be2cf89f2fd6aa9eaa1da44a683b032218745aeab4bd8e4159bce457ab` |

---

## 5) Cast recipe

```bash
BASE=${BASE_RPC_URL:-https://mainnet.base.org}
POLY=${POLY_RPC:-https://polygon-bor-rpc.publicnode.com}
SCROLL=${SCROLL_RPC:-https://rpc.scroll.io}
BREAKER=0xd92482bb8a4Ac2F6B80cd1583D2b7AcB630759A8
GATE=0xf2a6cE82E89C347637e173Dd892385A118048982
COLD=0xBb3c14bBacD639797cB5c537fde370d1b7195521

cast call $BREAKER "armed()(bool)" --rpc-url $BASE
cast call $BREAKER "tripped()(bool)" --rpc-url $BASE
cast call $BREAKER "amoCount()(uint256)" --rpc-url $BASE
cast call $GATE "canMint()(bool)" --rpc-url $BASE
cast call $COLD "minBufferBps()(uint256)" --rpc-url $BASE
cast call 0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7 "bordersSecure()(bool)" --rpc-url $BASE
cast call 0x00cAe93dd7F8D3331fe697D8B636B550aD6D7211 "bordersSecure()(bool)" --rpc-url $POLY
cast call 0x2ab17e3c00D783F58B106De2fB1723b4915Da257 "bordersSecure()(bool)" --rpc-url $SCROLL
```

---

```
PROOF_AMO6_GREEN=1
BREAKER=0xd92482bb8a4Ac2F6B80cd1583D2b7AcB630759A8
BREAKER_DEPLOY_TX=0x5ad54e0534153c7229aa791f79b25eee0c78bf2e090e47e45d8cd70f4c5920d2
MINTGATE=0xf2a6cE82E89C347637e173Dd892385A118048982
MINTGATE_DEPLOY_TX=0x159f6a82afb99796ee9228f3b1343c8880423603d1383894605831db0ac17fac
CAN_MINT=false
MIN_BUFFER_BPS=3000
MIN_BUFFER_TX=0x4e626ef50bc939d1e31caec215d911a6c84e1bebb9997f9b9cfc53a33b275963
BORDERS=base:true:16,poly:true:8,scroll:true:10
AMO_COUNT=4
ARMED=true
TRIPPED=false
```
