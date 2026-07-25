# CrownElepanPsm — kingdom dollar clear

**Status:** built · fire with `FIRE_PSM=1` (deploy + optional seed/buy)

| | |
|--|--|
| Contract | `src/CrownElepanPsm.sol` |
| eUSD | `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a` (18dp) |
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` (6dp) |
| Peg | 1 eUSD ↔ 1 USDC |
| Fee | `feeBps` → Landing |
| Mint/burn | **Not required** — CDP alone mints eUSD; PSM holds inventory + USDC reserve |

## Why this is first

No Gauntlet. No PA maxIn. No disk unlock. King deploys and curates the clear.

`buyUsdc`: eUSD in → USDC out (sterilizes eUSD in PSM)  
`sellUsdc`: USDC in → eUSD out (grows dollar reserve)

## Fire

```bash
# Deploy
KING_GO=1 FIRE_PSM=1 \
forge script script/FireElepanPsm.s.sol:FireElepanPsm \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"

# Seed king eUSD inventory (optional)
KING_GO=1 FIRE_PSM=1 PSM=0x… SEED_EUSD=1 \
forge script script/FireElepanPsm.s.sol:FireElepanPsm \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"

# Clear eUSD → Landing once USDC reserve exists
KING_GO=1 FIRE_PSM=1 PSM=0x… BUY_USDC=700000000000 \
forge script script/FireElepanPsm.s.sol:FireElepanPsm \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
```

## Physics

Redeem size ≤ USDC reserve. First reserve dollar still comes from Morpho idle / PA / wire / OTC — then the PSM clears the kingdom’s eUSD book without another external door.
