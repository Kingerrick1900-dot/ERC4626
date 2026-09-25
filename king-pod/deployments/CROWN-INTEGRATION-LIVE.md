# CROWN INTEGRATION — LIVE on Base

**Status:** DEPLOYED · wired · armed  
**Gas reality:** Base L2 fees are **~$0.01–$0.13** per deploy / **≪ $0.01** per call — **not millions**. HOT is down to **~$0.001 ETH dust**, so the optional `firePayroll` needs a tiny ETH top-up (L1 data fee buffer), not a gas redesign.

---

## Live addresses

| Module | Address | Role |
|--|--|--|
| **CrownSpendVault** | `0xc3f2ACe4161B82dbceE08Ea636467D2C3bD72458` | Per-tx / daily caps · target allowlist · pause |
| **CrownLsrEusd** | `0x3edeD70F8ACa4472948E7D3AE3Ad95D63ECdda4F` | dForce-class LSR · USDC↔eUSD · `mintPayroll` |
| **CrownBammOcean** | `0xAb21623705493538e7E86AAcC79C0297427dc3B2` | Frax-BAMM spike · oracle-free √(x·y) on gUSD/eUSD |
| **CrownKingAgent** | `0x128d1b9c8Ad4c47C3BCc12d237e78B95EF46f6bA` | Observe + allowlisted fire · refuses gasPark |

### Wiring (verified on-chain)
- Agent → vault / lsr / bamm set  
- LSR `isMinter=true` · `operator(agent)=true`  
- Vault `agent` = CrownKingAgent · targets allowlisted  
- `observe()` returns Morpho eUSD idle ≈ **145.3M**

### Deploy txs (sample)
- Vault create `0x0c928c27…d20f`  
- LSR create `0x8a784017…4c3a`  
- BAMM create `0xb6da1b9f…540f`  
- Agent create `0x5e371d3a…4b29`  
- setMinter(LSR) `0x05137674…dff8`

---

## Tests
```
forge test --match-contract CrownIntegrationTest -vv
# 6/6 PASS
```

---

## Gas math (so nobody panics)

| Action | Gas | Typical Base price | ETH | USD @ $3k/ETH |
|--|--|--|--|--|
| Full stack deploy | ~7.05M | ~0.006 gwei | ~0.000042 | **~$0.13** |
| `firePayroll` | ~97k | ~0.003–0.006 gwei | ~0.0000003 | **≪ $0.01** |
| HOT balance now | — | — | ~0.000000307 | **~$0.001** |

Bottle-neck = **HOT ETH empty for L1 fee buffer**, not “million-dollar gas.” Top up HOT with **~$1 of ETH** and:

```bash
cast send 0x128d1b9c8Ad4c47C3BCc12d237e78B95EF46f6bA \
  "firePayroll(uint256)" 10000000000000000000000000 \
  --rpc-url $BASE_RPC --private-key $PRIVATE_KEY --legacy
```

---

## CN handoff checklist

| Item | Status |
|--|--|
| Blueprint audit (Yunfeng / dForce / DeSyn) | Done (freeze PR) |
| dForce-class LSR (`CrownLsrEusd`) | **LIVE** |
| Frax-BAMM spike (`CrownBammOcean`) | **LIVE** |
| Spend vault + CrownKingAgent | **LIVE** |
| Unit tests | **6/6 PASS** |
| First `firePayroll` | Pending **~$1 ETH** top-up |
| Builder MEV | Phase 2 (not in day-one agent) |

**Rotate HOT key** — pasted in chat for this build.
