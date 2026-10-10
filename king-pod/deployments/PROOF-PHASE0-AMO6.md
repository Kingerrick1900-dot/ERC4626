# PROOF — Phase 0 Item 1 · Confirm AMO 6

**Mode:** PROOF · live reads · not a claim  
**UTC:** 2026-10-06T08:08:29Z  
**Blocks:** Base **52242381** · Polygon **95045971** · Scroll **35290067**  
**Order:** `ORDER-PROCEED-ELEPHANT.md`  
**Law:** Publish the proof, not the claim. Claim fires only when all four Phase 0 items are green.

---

## Verdict: **GREEN**

| Check | Live result |
|--|--|
| `bordersSecure` Base / Polygon / Scroll | **true** / **true** / **true** |
| Epochs | **16** / **8** / **10** |
| Quantum (`CrownPqRegistry.keyCount`) | **4** · Dilithium + Kyber active |
| NAV attestation (Base `attestations(16)`) | NAV **255928771250431** ≥ threshold **220000000000000** · proof `0xc363eaf0…793ce` |
| NAV freshness | age **~54.7h** ≤ `maxStale` **8000000s** |
| CircuitBreaker | armed **true** · tripped **false** · amoCount **4** |
| MintGate | `canMint` **false** · unlocked **0** |
| ColdBuffer | `minBufferBps` **3000** (30%) · USDC bal **294101** |

---

## 1) bordersSecure × 3

| Chain | CrownZkAttest | Block | `bordersSecure()` | `epoch()` | `lastAttestTime` |
|--|--|--:|--|--:|--:|
| Base `8453` | `0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7` | 52242381 | **true** | 16 | 1791077271 |
| Polygon `137` | `0x00cAe93dd7F8D3331fe697D8B636B550aD6D7211` | 95045971 | **true** | 8 | 1791077249 |
| Scroll `534352` | `0x2ab17e3c00D783F58B106De2fB1723b4915Da257` | 35290067 | **true** | 10 | 1791077246 |

No chain skipped.

---

## 2) Quantum signatures active

| Field | Value |
|--|--|
| `CrownPqRegistry` | `0xC92b1D9De2211A7ec3524708CBeBB21580fEDC95` |
| `keyCount()` | **4** |
| `activeDilithium()` | `0x1c70add8981d222a39b42e71a493c268d1c6ac0bd6b5af7d82afb2a17fc15207` · label `2035-run-200m` · active |
| `activeKyber()` | `0x58dc4d9d239788204a9f8c2bdbfbe388c149f89a11f7c6d13b902184e479b7b3` · label `2035-run-shield` · active |
| Also registered | `king-root` · `QKD-SZ-SHA-pilot-1` (both active) |

---

## 3) NAV attestation live and public (Base epoch 16)

| Field | Value |
|--|--|
| `yrss` | `0xF80C0529bD94C773844E459853CD91B9263dD525` |
| `navThreshold()` | `220000000000000` |
| `maxStale()` | `8000000` |
| Attested NAV | `255928771250431` |
| Cold field in attest | `294099` |
| Borders / snark / valid flags | **true** / **true** / **true** |
| Attest proof hash | `0xc363eaf0c5bf2203921cdd0b08fc3514afe52998b0c3797cd6af2a168b6793ce` |
| Attest timestamp | `1791077271` |
| Stale flag | **false** |

Polygon / Scroll mirrors: `bordersSecure=true`, `lastAttestTime` aligned (~1791077246–49).

---

## 4) AMO 6 armor (Base)

| Piece | Address | Live |
|--|--|--|
| CircuitBreaker | `0xd92482bb8a4Ac2F6B80cd1583D2b7AcB630759A8` | armed **true** · tripped **false** · amoCount **4** · yRssBaseline `255873051242331` |
| MintGate | `0xf2a6cE82E89C347637e173Dd892385A118048982` | canMint **false** · unlocked **0** |
| ColdBuffer | `0xBb3c14bBacD639797cB5c537fde370d1b7195521` | minBufferBps **3000** · USDC **294101** |

Deploy / set txs (prior, unreverted): see `PROOF-AMO6-GREEN.md`.

---

## Cast recipe (reproduce)

```bash
BASE=https://mainnet.base.org
POLY=https://polygon-bor-rpc.publicnode.com
SCROLL=https://rpc.scroll.io
BREAKER=0xd92482bb8a4Ac2F6B80cd1583D2b7AcB630759A8
MINT=0xf2a6cE82E89C347637e173Dd892385A118048982
COLD=0xBb3c14bBacD639797cB5c537fde370d1b7195521
PQ=0xC92b1D9De2211A7ec3524708CBeBB21580fEDC95
BA=0xe3Be837a6Bc915bF8FB1676581E423dA03cC14E7
PA=0x00cAe93dd7F8D3331fe697D8B636B550aD6D7211
SA=0x2ab17e3c00D783F58B106De2fB1723b4915Da257

cast call $BREAKER "armed()(bool)" --rpc-url $BASE
cast call $BREAKER "tripped()(bool)" --rpc-url $BASE
cast call $MINT "canMint()(bool)" --rpc-url $BASE
cast call $COLD "minBufferBps()(uint256)" --rpc-url $BASE
cast call $PQ "keyCount()(uint256)" --rpc-url $BASE
cast call $BA "bordersSecure()(bool)" --rpc-url $BASE
cast call $PA "bordersSecure()(bool)" --rpc-url $POLY
cast call $SA "bordersSecure()(bool)" --rpc-url $SCROLL
cast call $BA "attestations(uint256)(uint256,uint256,uint256,bool,bool,bool,bytes32,uint256,bool)" 16 --rpc-url $BASE
```

---

```
PROOF=PHASE0_AMO6
STATUS=GREEN
BORDERS=base:true:16,poly:true:8,scroll:true:10
PQ_KEYCOUNT=4
NAV=255928771250431
NAV_THRESHOLD=220000000000000
ARMED=true
TRIPPED=false
CAN_MINT=false
MIN_BUFFER_BPS=3000
BLOCKS=base:52242381,poly:95045971,scroll:35290067
NEXT=PHASE0_ITEM2_CROWNGATE_V2
```
