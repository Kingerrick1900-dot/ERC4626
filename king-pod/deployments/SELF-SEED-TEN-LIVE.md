# $10 oracle self-seed — LIVE

Self-seed fired. Draft APIs corrected to Morpho Blue. Matched book armed.

| | |
|--|--|
| Oracle `$10` (1e35) | [`0x04aa048DCb46FC80e9Ebd0717612c9fFF834f385`](https://basescan.org/address/0x04aa048DCb46FC80e9Ebd0717612c9fFF834f385) |
| Helper | [`0x4A39FAD3Fe149dE3445c9DfF29B1D703e4c9FFb2`](https://basescan.org/address/0x4A39FAD3Fe149dE3445c9DfF29B1D703e4c9FFb2) |
| Market id | `0x96228d1eae39767dda3053b36301b220b74a78adca6ffac5ad6c8b155e51d7cc` |
| LLTV | **91.5%** |
| Seed tx | [`0x6b6d75dc…8ef08`](https://basescan.org/tx/0x6b6d75dc4f21afcb8958a7e82a5129beaf1b1199ff816b3034193580ac18ef08) |

## Book (king hot)

| Leg | Amount |
|--|--|
| ELE collateral | **~13,999,940.246448 ELE** (8dp) |
| USDC supply | **$700,000** |
| USDC borrow | **$700,000** |
| Market idle | **~$0** (matched) |
| Hot wallet USDC | **$1** (Δ = 0 from seed) |
| Hot wallet ELE | **0** (posted) |

## Sequence that ran

1. Deploy `CrownFixedOracle(1e35)`  
2. `createMarket` ELE/USDC @ 91.5%  
3. `setAuthorization(helper)`  
4. Flash $700k → `supply` onBehalf king → `borrow` onBehalf king → repay flash  

## Draft bugs fixed before fire

- Callback: `onMorphoFlashLoan(uint256,bytes)` — **no fee**  
- `supply` / `supplyCollateral` 5th/4th arg = **`bytes data`**, not receiver  
- Flash repay = **approve** Morpho pull, not `transfer`  
- ELE amount = **14M × 1e8**, not 1e18  

## Fire again (resize)

```bash
KING_GO=1 FIRE_SELF_SEED_TEN=1 SEED_USDC=700000000000 \
forge script script/FireSelfSeedTen.s.sol:FireSelfSeedTen \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
```
