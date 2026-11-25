# AUDIT — Move 3 KAR Rebalancer (Scribe stub vs live Morpho)

**Status:** Stub `KAR_REBALANCER.py` as handed off is **unsafe / non-functional**.  
**Deliverable:** Corrected `offchain/KAR_REBALANCER.py` + `src/KarSniper.sol` + `script/KarRebalancer.s.sol`

---

## Fatal errors in the Scribe Python stub

| Stub claim | Reality |
|--|--|
| `allocator.reallocate(vault, bytes)` | Wrong ABI. Live fn is `PublicAllocator.reallocateTo(vault, Withdrawal[], MarketParams)` |
| GraphQL `api.morpho.org/graphql` | Deprecated (retire → REST `/v0/...`). Use REST + RPC |
| Sum foreign cbBTC/WETH **market** idle → pull into ySYNTH | **Impossible.** PA only reallocates **within one vault** that already holds those deposits |
| Placeholder PA / ySYNTH / market ids | Live: PA `0xA090…0467`, yRSS `0xF80C…D525`, RSS mkt `0x40ac…b794` |
| Hardcoded `PRIVATE_KEY = "KAR_OPERATOR_KEY"` | Never. Env-only. Dry-run default |
| 30s loop auto-fire `$100k` | Dangerous while pullable=0; corrected script defaults dry |

---

## Live board (checked)

- yRSS `totalAssets` ≈ **$417M** (matched Path B book), but **cbBTC/WETH positions on yRSS = $0**
- Fat holdings are on eUSD/RSS markets at **~100% util** → **pullable idle ≈ $0**
- Morpho REST: RSS market `reallocatable_liquidity = 0`, `public-allocator-vaults = []`
- Foreign cbBTC market shows large `reallocatable_liquidity` — that fills **cbBTC/USDC** for borrowers **on that market** (Move 4), not yRSS shares
- yRSS allocations endpoint: **blacklisted** on Morpho REST → rebalancer must use **RPC** for own vault

---

## Corrected 5-move read (pre-execution)

1. **Copy params** — OK as curator work (own markets). Does not create USDC.  
2. **Legal armor** — Do **not** copy Aave/Kamino/Veda legal text verbatim (copyright). Counsel drafts KE-Sov wrapper.  
3. **Rebalancer** — This PR. Own-vault PA sniper only.  
4. **cbBTC path** — First external dollar: post cbBTC/WETH, borrow USDC on blue-chip markets (optionally PA-fill *those* markets first).  
5. **Scale** — Only after liquid USDC exists; 100k is a test size, not a magic.

---

## KAR deploy parameters

### A) Off-chain (primary — Steakhouse pattern)

```bash
cd king-pod
# Dry board read:
python3 offchain/KAR_REBALANCER.py

# Evaluate $100k ask (no broadcast):
REQUIRED=100000000000 python3 offchain/KAR_REBALANCER.py

# Fire once (HOT / allocator key):
REQUIRED=100000000000 BROADCAST=1 PRIVATE_KEY=0x... python3 offchain/KAR_REBALANCER.py
```

### B) On-chain sniper (optional executor)

```bash
cd king-pod
forge install foundry-rs/forge-std --no-commit   # once
forge build --skip test
forge script script/DeployKarSniper.s.sol:DeployKarSniper --rpc-url $RPC --broadcast
```

| Param | Value |
|--|--|
| morpho | `0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb` |
| publicAllocator | `0xA090dD1a701408Df1d4d0B85b716c87565f90467` |
| vault (yRSS) | `0xF80C0529bD94C773844E459853CD91B9263dD525` |
| kingVault | `0xA1aFcb46a64C9173519180458C1cF302179c832a` |
| operator | HOT `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |

Before borrow path: `Morpho.setAuthorization(KarSniper, true)` from HOT.

### C) Expected live result today

`SKIP: yRSS source idle < required` until curator deposits / util frees pullable liquidity on yRSS source markets — **or** Move 4 posts blue-chip collateral and borrows foreign idle directly.

---

## Bottom line

The “10-line Steakhouse” bot is real **as an off-chain PA caller**. The Scribe stub pointed it at the wrong ABI and the wrong liquidity. Corrected code ships; it will honestly NOOP until yRSS has pullable idle.
