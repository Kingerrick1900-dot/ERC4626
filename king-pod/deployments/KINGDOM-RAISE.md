# Kingdom raise — the stack we are

| Pillar | Live |
|--|--|
| Allocation / curation | yELE `0x61bf…145E` — owner + curator = King `0x6708…a7d1` |
| Oracle | ELE/USDC fixed `$1` `0xe290…cf19` (Morpho price `1e34`) |
| Shares | King free ELE **14M** · Morpho coll **~86M ELE** · loan engine debt **~$50M** |
| Loan engine | Morpho Blue ELE/USDC `0xa4ec…53fc` · LLTV 77% |
| Cash door | Gauntlet Prime already supplies **~$26M** into WETH/USDC Blue · market idle **~$7.5M** |
| Extractor | `0x3734…8947` armed → Landing `0x5Adc…2357` |

The kingdom does not wait on a foreign protocol story. We curate, we allocate, we borrow against ELE. The raise is the loan engine drawing real idle into Landing.

## Raise fire (when PA door open)

```bash
KING_GO=1 FIRE_CASH=1 ASK_USDC=700000000000 \
forge script script/FireCashHunt.s.sol:FireCashHunt \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
```

Scan only:

```bash
KING_GO=1 FIRE_CASH=1 SCAN_ONLY=1 forge script script/FireCashHunt.s.sol:FireCashHunt \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY"
```

## Fork proof

`CashHuntGauntletForkTest` — open Gauntlet ELE cap + WETH maxOut / ELE maxIn → PA WETH→ELE → Landing **~$700k**.
