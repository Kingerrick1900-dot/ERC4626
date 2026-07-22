# Vault V2 — Seven Steps (King plan)

| Step | Action | Status |
|------|--------|--------|
| 1 | Deploy Morpho Vault V2 (USDC); King curator + allocator | **LIVE** `0xB96BcfFBB458581a3AF7fEd3150B7CD4b233A7b9` |
| 2 | Add RSS/USDC market to allowed markets | **LIVE** caps open |
| 3 | `liquidityAdapter` → RSS/USDC market | **LIVE** adapter `0x3088de5b…EE8c` |
| 4 | Deposit USDC (even $1) | **LIVE** ~$1 dead seed → vault TVL |
| 5 | Vault USDC in RSS Morpho market | **LIVE** market idle ≈ vault seed |
| 6 | Post RSS collateral | **FIRED** — 1,000,000 RSS posted |
| 7 | Borrow USDC → Landing | **FIRED** — **1,000,346** USDC raw (~$1.00) → Landing |

Owner = Landing · Curator/Allocator = Hot.

**Draw proof:** `broadcast/FireVaultV2SevenSteps.s.sol/8453/run-latest.json` · `SEVEN_STEPS_OK=1`  
Path works end-to-end. Scale = more USDC into vault → more idle → larger Landing borrow.

## Fire

```bash
# Verify 1–5
KING_OK=1 FIRE_V2_SEVEN=1 forge script script/FireVaultV2SevenSteps.s.sol \
  --rpc-url $BASE_RPC --broadcast --chain 8453

# Steps 6–7 — borrow all market idle to Landing
KING_OK=1 KING_GO=1 FIRE_V2_SEVEN=1 DRAW=1 \
  forge script script/FireVaultV2SevenSteps.s.sol \
  --rpc-url $BASE_RPC --broadcast --chain 8453
```

**Scale law:** borrow size = USDC sitting in the RSS market (vault-allocated). More Kingdom USDC into the vault → more Landing draw. Plumbing is done; size follows deposits King controls.
