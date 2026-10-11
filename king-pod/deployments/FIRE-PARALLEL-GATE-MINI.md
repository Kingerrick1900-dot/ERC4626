# FIRE — Parallel Gate Mini (Safe King at birth)

**Status:** **LIVE** · no Safe accept · jammed queue bypassed  
**Market:** `0x1bfd981b9905c55085390f7dedad00f32cd43527acf9dabe7de758e3f6c42134` · LLTV 38.5%

---

## Live

| Field | Value |
|--|--|
| **Mini Gate** | `0x1Fc2c07982B5C01D18f924da95F9B117a8598E6F` |
| king | **Safe** `0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0` |
| pendingKing | `0x0` |
| operator HOT | **true** |
| zkGate | `0x3fF6a7E336aFF445F6C8D6CBad1135a49b4B7091` |
| Deploy tx | see `broadcast/FireParallelGateMini.s.sol/8453/run-latest.json` |

## Why

Old Gate `0x8Bbd…` needed Safe `acceptKingship`; Safe nonce queue was jammed with dead MultiSends. Mini Gate sets **Safe as King in the constructor** and HOT as operator — no accept, no queue.

## Ignore

- Gate `0x8Bbd…` — leave it; pending accept optional / abandon  
- Stuck Safe nonces 1–2 — irrelevant to Mini Gate  

```
FIRE_PARALLEL_GATE_MINI=1
MINI_GATE=0x1Fc2c07982B5C01D18f924da95F9B117a8598E6F
KING=SAFE
OPERATOR=HOT
MARKET=0x1bfd981b9905c55085390f7dedad00f32cd43527acf9dabe7de758e3f6c42134
ACCEPT=NOT_REQUIRED
```
