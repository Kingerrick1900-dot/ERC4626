# CrownElepanPsm — kingdom dollar clear

**Live:** [`0x9199E5099C2C46A688F982E377a146Ab6db8060b`](https://basescan.org/address/0x9199E5099C2C46A688F982E377a146Ab6db8060b)  
**Deploy tx:** [`0x4d0f73d1…fa6637`](https://basescan.org/tx/0x4d0f73d1bc5e04b3bc7ba68dbbf471264832dec2407e49a14aff230e87fa6637)

| | |
|--|--|
| Contract | `src/CrownElepanPsm.sol` |
| eUSD | `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a` (18dp) |
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` (6dp) |
| Peg | 1 eUSD ↔ 1 USDC |
| Fee | `feeBps` → Landing |

## Seed policy (gas first)

- **Go-live = deploy + tiny dollar reserve.** Do not drain hot.
- Seed **only** sized amts: `SEED_USDC_AMT` / `SEED_EUSD_AMT` / `IDLE_TO_PSM_USDC`.
- Legacy full-balance `SEED_USDC=1` / `SEED_EUSD=1` is **rejected**.
- Keep `MIN_ETH_WEI` (default `3e14` ≈ 0.0003 ETH) on hot for later fires.
- Landing holds ~$59 USDC (needs `LANDING_KEY` to move). Prefer `IDLE_TO_PSM_USDC` for a minimal Morpho-dust seed.
- Redeem size ≤ USDC reserve. Do not park payroll USDC in the PSM beyond the clear you intend.

## Fire

```bash
# Deploy only (preferred go-live)
KING_GO=1 FIRE_PSM=1 \
forge script script/FireElepanPsm.s.sol:FireElepanPsm \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"

# Seed a sized slice later (example $1k USDC) — never full wallet
KING_GO=1 FIRE_PSM=1 PSM=0x9199E5099C2C46A688F982E377a146Ab6db8060b \
  SEED_USDC_AMT=1000000000 \
forge script script/FireElepanPsm.s.sol:FireElepanPsm \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"

# Clear eUSD → Landing once reserve covers ask
KING_GO=1 FIRE_PSM=1 PSM=0x9199E5099C2C46A688F982E377a146Ab6db8060b \
  BUY_USDC=1000000000 \
forge script script/FireElepanPsm.s.sol:FireElepanPsm \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
```

## Legs

`buyUsdc`: eUSD in → USDC out (sterilizes eUSD in PSM)  
`sellUsdc`: USDC in → eUSD out (grows dollar reserve from inventory)
