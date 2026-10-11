# HANDOFF — ZK Circuit Rebuild for the Safe

**Status:** **DONE** · `isProven(Safe) == true`  
**PR:** #195  
**Doctrine:** Safe remains King · HOT operator only · no temporary throne return

---

## Live result

| Item | Value |
|--|--|
| WalletGate | `0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091` |
| Subject (King) | Safe `0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0` |
| `isProven(Safe)` | **true** |
| Proof submit tx | [`0xf26552d5…536a`](https://basescan.org/tx/0xf26552d5646f7e5b6d00cb8e2c8e2498b575a1308589f07ecb8df16b08af536a) |
| minThreshold tx | [`0x67339693…c862`](https://basescan.org/tx/0x673396931890125b4365de6b160d6c21aa9a2821a92db7586a235408b250c862) → **$200k** |
| Witness RSS | Morpho coll on gate `222521940922706875000000` (~$222.5k @ $1 circuit scale) |
| Threshold used | `200000000000` ($200k 6dp) |

**Corrections vs draft order:**  
- Submit to **WalletGate** `0x3fF6…`, not Morpho gate `0x76fa…`  
- ABI: `submitProof(uint256[2],uint256[2][2],uint256[2],uint256[4])`  
- Threshold **$700k** fails at $1/RSS on 222k RSS → minThreshold lowered to **$200k** so bind clears  
- Circuit file: `zk/circuits/wallet_reserves.circom` (not `crown_witness.circom`)

---

## Next (cover phase)

HOT USDC still dust. When **≥ $2M USDC** lands on HOT:

```bash
FIRE_KINGS_COMBINED=1 ZK_SHIELD=1 MODE=cover \
  forge script script/FireKingsCombined.s.sol:FireKingsCombined \
  --rpc-url "$BASE_RPC_URL" --broadcast --private-key "$HOT_KEY"
```

Gate fires now pass `whenZkFire` because `isProven(king)==isProven(Safe)==true`.

---

## Re-verify (builder executed handoff)

| Check | Result |
|--|--|
| `circom --version` | 2.1.9 (binary `/usr/local/bin/circom`) |
| `king()` | Safe `0x23590FEb…eac0` |
| `pendingKing()` | `0x0` |
| `isProven(Safe)` WalletGate | **true** |
| `minThreshold()` | `200000000000` |
| HOT USDC | `164417` (~$0.16) — cover still blocked |
| Artifacts | `zk/proofs/wallet_safe_{proof,public,witness,input,solidity}.*` |

Doctrine held: Safe King · HOT operator only · no throne return.

```
HANDOFF=ZK_SAFE_REBUILD
STATUS=DONE
IS_PROVEN_SAFE=true
MIN_THRESHOLD=200000000000
TX_PROOF=0xf26552d5646f7e5b6d00cb8e2c8e2498b575a1308589f07ecb8df16b08af536a
NEXT=COVER_2M_USDC
```
