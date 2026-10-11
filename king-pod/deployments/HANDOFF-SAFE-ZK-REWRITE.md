# HANDOFF — Safe ZK-rewrite remaining Morpho eUSD (~1.32B Landing leg)

# CLICK THESE

1. **Safe home:** https://app.safe.global/home?safe=base:0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0
2. **Transaction Builder:** https://app.safe.global/apps/open?safe=base:0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0&appUrl=https%3A%2F%2Fapps-portal.safe.global%2Ftx-builder
3. Import `safe-zk-rewrite-batch.json` → sign → get 2nd owner → execute

Or open `king-pod/tools/safe-zk-rewrite.html`

---


**Status:** HOT ~301M **REWRITTEN** via `CrownZkMorphoRail` (on-chain ZK).  
**Remaining:** Safe still holds Morpho shares that include the Landing leg entered **before** the ZK rail. Safe must withdraw → `zkSupply` to bind the full book to the rail.

---

## Live

| Field | Value |
|--|--|
| ZK rail | `0xa787C47E04b38bcD84ceAd05ce903B0005E9Dda3` |
| Rail owner | Safe |
| Market | eUSD/RSS `0xc61adc055891c4edd3050480465aed2062d0480783f97604c63f8d1ccd8d0599` |
| Morpho | `0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb` |
| eUSD | `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a` |
| HOT Morpho shares | **0** (rewritten) |
| Safe Morpho shares | `812225182616319932301651205000000` |
| Rail `totalSupplied` | ~301M eUSD (HOT leg only so far) |
| `isProven(HOT/Safe)` | true / true |
| `bordersSecure` | true |

### HOT rewrite txs (done)

| Step | Tx |
|--|--|
| Deploy rail | [`0x80d6cfc6…737c`](https://basescan.org/tx/0x80d6cfc67a1feae24399a01ff78f5a9bb8cd4812b3fe6a6796f48f9320db737c) |
| Withdraw + zkSupply | see `broadcast/FireZkRewriteHotSpoil.s.sol/8453/run-latest.json` |

---

## Safe 2-of-3 MultiSend (King signs)

Connect Safe `0x23590FEb…eac0` on Base. Propose **one MultiSend** with 3 txs:

### Tx1 — Morpho `withdraw` (all Safe shares → Safe)

- To: `0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb`
- Data: `withdraw(marketParams, 0, SAFE_SHARES, Safe, Safe)`
- `SAFE_SHARES` = current `position(EUSD_RSS, Safe).supplyShares` (read live before signing)

### Tx2 — eUSD `approve` ZK rail

- To: `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a`
- Data: `approve(0xa787C47E04b38bcD84ceAd05ce903B0005E9Dda3, type(uint256).max)`

### Tx3 — ZK rail `zkSupply`

- To: `0xa787C47E04b38bcD84ceAd05ce903B0005E9Dda3`
- Data: `zkSupply(eusdBalance, Safe)`  
- `eusdBalance` = eUSD balance of Safe after withdraw  
- Reverts unless `isProven(Safe)` + `bordersSecure` (on-chain)

Needs **2 of 3** owners (Landing / `0x898D…` / `0x5E07…`).

### Verify after

```bash
cast call 0xa787C47E04b38bcD84ceAd05ce903B0005E9Dda3 "totalSupplied()(uint256)" --rpc-url https://mainnet.base.org
# ~1.624e27
cast call 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb \
  "position(bytes32,address)((uint256,uint128,uint128))" \
  0xc61adc055891c4edd3050480465aed2062d0480783f97604c63f8d1ccd8d0599 \
  0x23590FEb2A668817a426d46A0447Ed3ea8e3eac0 --rpc-url https://mainnet.base.org
```

```
HOT_ZK_REWRITE=DONE
SAFE_ZK_REWRITE=AWAIT_2OF3
ZK_RAIL=0xa787C47E04b38bcD84ceAd05ce903B0005E9Dda3
```

Say **check again** when Safe MultiSend executes.
