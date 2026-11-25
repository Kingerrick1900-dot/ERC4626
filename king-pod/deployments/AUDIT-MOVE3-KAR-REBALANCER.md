# AUDIT — Move 3 Scribe stub vs live KAR stack

**Verdict:** The pasted `KAR_REBALANCER.py` stub is **broken**. Do not deploy it.  
**Live stack already correct:** `CrownKarReallocator` + `kar/reallocator.py`

---

## Scribe stub — fatal errors

| Stub | Truth |
|--|--|
| `reallocate(vault, bytes)` ABI | Wrong. Use `PublicAllocator.reallocateTo(vault, Withdrawal[], MarketParams)` |
| GraphQL `api.morpho.org/graphql` | Deprecated. Prefer RPC + REST `/v0/...` |
| Sum **foreign** cbBTC/WETH market idle → ySYNTH | **Impossible.** PA is **intra-vault only** |
| Placeholder PA / vault / market ids | Live addresses below |
| Hardcoded `PRIVATE_KEY = "KAR_OPERATOR_KEY"` | Env-only. Dry-run default |
| Auto-fire `$100k` every 30s | Unsafe while pullable=0 |

---

## Live board (already fired on this branch)

| Item | Value |
|--|--|
| **CrownKarReallocator** | `0xA6F695dE7FE2C957f206b6374e6A8a96fA0758a0` |
| ySYNTH-USDC | `0xc91f3Bc556001eF7ACFCB869eC0fC29ac780c35C` |
| PublicAllocator | `0xA090dD1a701408Df1d4d0B85b716c87565f90467` |
| Watcher | `king-pod/kar/reallocator.py` |
| First pull | **$0** (no ySYNTH shares in cbBTC/WETH side books) |
| Blocker | Foreign maxIn=0 · side-book shares=0 · target util ~100% |

See `KAR-REALLOCATOR.md` for full scoreboard.

---

## Corrected 5-move read

1. **Copy params** — curator work; does not mint USDC.  
2. **Legal armor** — do **not** copy Aave/Kamino/Veda legal text verbatim (copyright). Counsel drafts.  
3. **Rebalancer** — **DONE live** (module + watcher). Physics honest: NOOP until side-book shares or foreign maxIn.  
4. **cbBTC path** — first external dollar: post cbBTC/WETH, borrow on blue-chip markets (foreign idle lives *there*).  
5. **Scale** — only after liquid USDC exists.

---

## What this PR adds

| File | Role |
|--|--|
| `offchain/KAR_REBALANCER.py` | Corrected drop-in replacing the Scribe stub (yRSS PA sniper + REST diagnostic). Dry-run default. |
| `src/KarSniper.sol` + `DeployKarSniper.s.sol` | Optional thin executor. Prefer live `CrownKarReallocator` (`0xA6F695…`). |
| `script/KarRebalancer.s.sol` | Forge one-shot PA pull for yRSS RSS market. |
| `kar-sniper-params.json` | Deploy constructor params. |

### KAR commands (use live watcher)

```bash
cd king-pod
python3 kar/reallocator.py --once          # dry
FIRE=1 python3 kar/reallocator.py --once   # broadcast via module/PA
```

### Stub-replacement dry (yRSS)

```bash
python3 offchain/KAR_REBALANCER.py
REQUIRED=100000000000 python3 offchain/KAR_REBALANCER.py
# Live result: SKIP — yRSS/ySYNTH source idle << required; foreign idle not siphonable
```

---

## Bottom line for Builders / KAR

Ship **nothing** from the Scribe Python paste. The rail is already live; the seed is not. Next: Move 4 (post blue-chip → borrow foreign idle) or park real USDC in ySYNTH side books so the watcher can `reallocateTo`.
