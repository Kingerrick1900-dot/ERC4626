# Base USDC PSM — Maker mint/redeem

**Play:** Unblock external minting. Peg defense on Base without Scroll hop.

| | |
|--|--|
| Contract | `src/CrownBaseUsdcPsm.sol` |
| eUSD | `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a` (18dp) |
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` (6dp) |
| Peg | 1 eUSD ↔ 1 USDC |
| Fee | `feeBps` → Landing (default 0) |

## Legs

| Call | Direction | Effect |
|------|-----------|--------|
| `mint(usdc, to)` | USDC → eUSD | Mints eUSD; USDC stays as redeem reserve |
| `redeem(eusd, to)` | eUSD → USDC | Burns eUSD; pays USDC from reserve |
| `seedUsdc(amt)` | King only | Capitalize redeem floor (explicit amt) |

PSM **must** be `eUSD.setMinter(psm, true)` (hot owns eUSD).

## vs inventory PSM

Older inventory clear [`0x9199E509…060b`](https://basescan.org/address/0x9199E5099C2C46A688F982E377a146Ab6db8060b) (`CrownElepanPsm`) holds eUSD inventory — does **not** mint. This module is the Maker rail for the flywheel.

## Sequence

1. **Deploy + setMinter** — zero-slippage mint/redeem live  
2. **Seed USDC** — capitalize peg floor before scaling WETH/cbBTC CDP debt  
3. Then external coll mint → redeem → Morpho loop unlocks

## Fire

```bash
# Deploy + wire minter (no seed)
KING_GO=1 FIRE_BASE_USDC_PSM=1 \
forge script script/FireBaseUsdcPsm.s.sol:FireBaseUsdcPsm \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"

# Seed explicit USDC (never full-drain flags)
KING_GO=1 FIRE_BASE_USDC_PSM=1 PSM=0x… SEED_USDC_AMT=1000000000 \
forge script script/FireBaseUsdcPsm.s.sol:FireBaseUsdcPsm \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
```

## Live

_Pending fire — fill address + txs after broadcast._
