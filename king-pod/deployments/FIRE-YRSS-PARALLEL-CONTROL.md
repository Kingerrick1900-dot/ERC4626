# FIRE — yRSS Parallel Control (King command surface)

**Mode:** FIRE · Base · **LIVE**  
**Order:** Seize yRSS control · charge parallel rail · Safe curator/allocator  
**Vault:** `0xF80C0529bD94C773844E459853CD91B9263dD525`

---

## Executed

| Step | Result | Tx |
|--|--|--|
| submitCap + acceptCap parallel | **enabled** · cap **$50M** | [`0x95287ac2…d75a`](https://basescan.org/tx/0x95287ac2f4d2c565540d7870c2bb17af6e4f347daa856cde39104521e984d75a) · [`0x56e8296f…9d7a`](https://basescan.org/tx/0x56e8296f64c68dc3c3b8cb8eef8159abcd25ba4dece8bc3e037fe4496d1e9d7a) |
| setSupplyQueue (PAR first) | queue[0] = parallel | [`0x6762db3d…32f7`](https://basescan.org/tx/0x6762db3deaf79694d3b5505a323d689dd99e32cf888d29781eddbbd76e8632f7) |
| PA setFlowCaps | maxIn/maxOut **$50M** | [`0x057a8c22…0f33`](https://basescan.org/tx/0x057a8c228ff7331b830c47ab8e180ca8bc5d423b18d40e2ff4762472a1150f33) |
| setIsAllocator(Safe) | **true** | [`0xa506bf5d…e34c`](https://basescan.org/tx/0xa506bf5dbfb7bf1242a71e223a599b50b9df088b17be0b201f3da7542265e34c) |
| setCurator(Safe) | Safe | [`0xbac583e8…441a`](https://basescan.org/tx/0xbac583e8a6ca424026e477bcd67c0f2d6786b87a32e68f26526fadbabc6e441a) |

## Live control board

| Role | Address |
|--|--|
| owner | HOT `0x6708…a7d1` (gas ops) |
| curator | **Safe** `0x23590FEb…eac0` |
| allocator Safe | **true** |
| allocator HOT | true |
| PA admin | HOT |
| Parallel market | `0x1bfd981b9905c55085390f7dedad00f32cd43527acf9dabe7de758e3f6c42134` |
| Parallel on supplyQueue | **index 0** |
| Parallel on withdrawQueue | **yes** (len 11) |
| Parallel cap / PA | **$50M** / **$50M·$50M** |

## Meaning

yRSS now **points at** the King's parallel 38.5% rail first. Safe holds curator + allocator. New USDC into yRSS charges `0x1bfd…` before legacy books. Stuck util on legacy Morpho supply is unchanged by this wire — the command surface and destination rail are live.

## Next

1. Safe `acceptKingship()` on parallel Gate `0x8Bbd…B2B9`  
2. When liquid USDC appears: it lands on parallel via queue[0] / PA  
3. Optional later: transfer yRSS `owner` → Safe

```
FIRE_YRSS_PARALLEL_CONTROL=1
PAR=0x1bfd981b9905c55085390f7dedad00f32cd43527acf9dabe7de758e3f6c42134
PAR_CAP=50000000000000
CURATOR=SAFE
ALLOCATOR_SAFE=true
SUPPLY_QUEUE_0=PAR
NEXT=SAFE_ACCEPT_PARALLEL_GATE
```
