# What’s Blocking the \$700K Seed

**Scribe. Work-to-completion board.**

---

## ONE real blocker

| Blocker | Detail |
|---------|--------|
| **No USDC has entered a settle rail** | Credit V2 balance **\$0** · Desk raised **\$0** · Cold **\$0** · Hot USDC **~\$7** |

Everything else for the \$700k seed is **done**. The seed is waiting on **inbound USDC** (counterparty wire / credit `supply` / desk buy).

---

## NOT blocking (cleared today)

| Rail | State |
|------|--------|
| CDP 1M RSS → 700k kUSD on hot | **LIVE** |
| ZK `isProven(hot)` ≥ \$700k | **LIVE** |
| Credit V2 `borrowTo(cold)` atomic | **LIVE** · LLTV 100% |
| Desk 700k RSS @ \$1 → Landing | **LIVE** |
| Packets / settle addresses | **ARMED** |

---

## Three fill doors (any one completes the seed)

| Door | Counterparty action | Our capture |
|------|---------------------|-------------|
| **A** OTC | Wire \$700k USDC → Landing | Done on receipt |
| **B** Credit | `supply(\$700k)` → V2 `0x01814e15…BaBA54` | Auto `borrowTo(cold)` |
| **C** Desk | `buy` 700k RSS @ \$1 | USDC → Landing same tx |

---

## Completion today (Kingdom side)

1. Blocker board = this doc  
2. **Auto-capture daemon** — polls Credit V2 + desk raised + Landing; fires atomic draw the second credit has USDC  
3. Counterparty packet stays: `SECURE-700K-TOTAL.md`

```bash
# Run until seed hits cold (or King stops)
AUTO_FIRE=1 KING_OK=1 bash script/capture-zk-700k.sh
```

**Done when:** Landing (cold) USDC ≥ \$700k **or** desk raised ≥ \$700k.
