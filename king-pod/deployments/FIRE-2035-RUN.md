# FIRE — The 2035 Run (Full 200M · ZK-Proven · Quantum-Signed)

**Mode:** FIRE · executed on Base  
**Doctrine:** ZK proves it. Quantum signs it. NFC triggers it. Mint · Curate · Earn · Exit.  
**Chassis:** LIVE addresses from `FIRE-NATIVE-LOOP.md` · `FIRE-QUANTUM-YIELD-ENGINE.md` · `FIRE-SPOIL-QKD-FINISH.md`

---

## LIVE stack

| Module | Address |
|--|--|
| **CrownCuratorNative** | `0x8Cb11A67F9734143195b24D179749534099b7558` |
| **CrownExitNative** | `0x97bd68464709A61D70D70d4A6027A5Bb9e80bB68` |
| **StarkSnarkBridge** | `0x0E88d44F0a6dbD9FF1849DB18278388d74562B07` |
| **PqRegistry** | `0xC92b1D9De2211A7ec3524708CBeBB21580fEDC95` |
| **EasyTrigger** | `0x512c8ee4521474c2a2E56C033072d56f1998cc6d` |
| **QkdPilotV2** | `0x96f275AEDe2a8802D52D25ef866DCCc50D038f9a` |
| **ZkSettlementGate** | `0x7c48a7fAA294C4b04002f65FA03F7C5ce952B637` |
| Ocean / Pendle / Aave-eUSD | `0xAb21…c3B2` · `0x0322…3429` · `0x3c55…C441` |

---

## What fired

| Step | Result | Proof |
|--|--|--|
| 1. ZK-Prove 200M + yRSS gold | `commitStark` + `attestLive` · epoch **14** · borders **true** | [`0x650fdefd…aa78`](https://basescan.org/tx/0x650fdefdc6386d959bd4114cddda24941f7ee8da4e44a3f01001c59fc495aa78) · [`0xcc6bd623…5454`](https://basescan.org/tx/0xcc6bd62326bbc798947b748786bc283d2f7af11f6d4561e9cbabccf1ef425454) |
| 1b. Settlement SNARK | `submitProof` · `canFill=true` · `SETTLEMENT_ZK_LIVE=1` | [`0x5499b920…fb34`](https://basescan.org/tx/0x5499b920978b64f76db118a60669dd8c78302759d4476d1dc0add451276efb34) |
| 2. Quantum-Sign | Dilithium `2035-run-200m` + Kyber `2035-run-shield` **active** | activate [`0x0afd13b3…52a6`](https://basescan.org/tx/0x0afd13b345757e73940295f59ef94aa5780e7c85029356554562db6a570c52a6) · [`0x112e0d89…f6af`](https://basescan.org/tx/0x112e0d890061cda1c030c18f8ebba3dd52c83365e1d92cc9f5ac061c8db8f6af) |
| 2b. QKD packet | packets=**2** · King `attestLive` | [`0x52ed2f61…e878`](https://basescan.org/tx/0x52ed2f61a60059ded15a15c8f10159a93b915179106d160c6a7ee46d9eb6e878) |
| 2c. EasyTrigger NFC | `submitNfcReceipt` | [`0x1abd379c…f1e1`](https://basescan.org/tx/0x1abd379c57ac7363cd6b1891cdf475ee79e6bc738b4c99c5acfc769ee60df1e1) |
| 3. Curator 200M split | Ocean **100M** · Pendle **50M** · Aave-eUSD **~50M** | already allocated (Path C CLOSED) |
| 4–5. ExitNative | Cold inventory **0** → exited **0** USDC this run | `NEXT=scale Exit inventory` (`FIRE-NATIVE-LOOP.md`) |

**lastStarkRoot:** `0x6617f9a3d1e417d5db902650356f8439ba52604f110b88ff91553b92dd388e07`  
**activeDilithium:** `0x1c70add8981d222a39b42e71a493c268d1c6ac0bd6b5af7d82afb2a17fc15207`  
**activeKyber:** `0x58dc4d9d239788204a9f8c2bdbfbe388c149f89a11f7c6d13b902184e479b7b3`  
**yRSS gold rail:** `totalAssets` ≈ **$240.56M** (USDC 6dp)

Script: `script/Fire2035Run.s.sol` · broadcast `broadcast/Fire2035Run.s.sol/8453/run-latest.json`

---

## Scoreboard (live)

```
SCOREBOARD=HOT_HARD_ASSETS
hotUsdc=1.330485
hotCbBtc=1.028e-05
hotWeth=0.0
hotEusd=201000000.000001
nativeMinted=200000000.0
IGNITION=YES
```

```
FIRE=2035-run ✓
ZK=stark+attest+settlement ✓ epoch=14
PQ=dilithium+kyber 2035 active ✓
QKD_V2=packets=2 ✓
NFC=easyTrigger receipt ✓
CURATOR=200M Ocean100/Pendle50/Aave50 ✓
EXIT=cold=0 exited=0
NEXT=scale Exit inventory → FireNativeLoopFinishLean → leave ops dust on HOT
```
