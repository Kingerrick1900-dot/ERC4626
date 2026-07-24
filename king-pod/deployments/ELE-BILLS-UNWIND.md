# ELE Bills Unwind — spendable path

## Order
1. Move **yELE** Landing → Hot (one transfer)  
2. Fire unwind (no loop)  
3. Books clean · Elepan free · surplus USDC → Landing  
4. Then Morpho-right borrow → Landing **KEEP** when idle exists (bills)

## Why yELE must sit on Hot
Landing holds the vault shares that are the ~$14M USDC. Hot key cannot redeem Landing’s shares without that transfer/approve. MetaMorpho blocks owner skim/reallocate-out.

## Fire
```bash
# after yELE on hot:
KING_GO=1 FIRE_ELE_BILLS=1 forge script script/FireElepanBills.s.sol:FireElepanBills \
  --rpc-url $BASE_RPC --broadcast --slow
```

## Fork
`EleUnwindDebug` + `ElepanBillsForkTest` — debt 0, coll 0, ~76M Elepan free.

## Truth on $500k
Matched self-loop cannot mint net $500k out of thin air. Unwind cleans the bad loan. Spendable $500k = Morpho borrow KEEP after real idle (or matcher). No recycle.
