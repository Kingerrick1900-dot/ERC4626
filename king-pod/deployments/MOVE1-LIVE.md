# Move 1 — LIVE

**Fired on King GO. Base.**

| Action | Size | Tx |
|--|--|--|
| Morpho `withdrawCollateral` | **20,142,844.62 Elepan** → hot | [`0xe5c62b04…56ca`](https://basescan.org/tx/0xe5c62b04bb129f4c0cd23a4844547fdaf7235cb5b08f0560d0b7a1927be956ca) |
| CDP `mintTo` Landing | **1,628,900 eUSD** | [`0xa22cfd4e…5752`](https://basescan.org/tx/0xa22cfd4e3b2b30356733eb0a08aa1cdb55ad2c1cde5f68522126d6d197805752) |
| CDP `withdraw` | **1,262,422.15 Elepan** → hot | [`0x305a2cec…47a7`](https://basescan.org/tx/0x305a2cec0e6c418793336dcb59e1e2d9a79346522b8d32dcaf27abb6954847a7) |

## Book after Move 1

| Meter | Live |
|--|--|
| Hot Elepan | **~55.98M** |
| Morpho coll (hot) | **~20.00M** · borrow **~$14.0M** kept |
| CDP coll | **~23.94M** |
| CDP debt / Landing eUSD | **~14.63M eUSD** |
| CDP HF | **~1.636** |
| ELE market idle | **0** (borrow not fired) |

## Next (Move 2 / 3)

- Curator packet live: `CURATOR-PACKET-ELE-USDC.md` — send for PA maxIn  
- ZK fill — King names supplier into credit → draw Landing  
- If idle **> 0** at any check: `FIRE_BORROW` same block
