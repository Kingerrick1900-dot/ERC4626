# ELE Bills Unwind — spendable path

## LIVE RESULT (Base) — DONE
- **Debt 0 · coll 0 · ~2.0M Elepan freed to Hot**
- yELE `totalAssets` ≈ dust (2 wei)
- Landing USDC surplus: **$5.649316** (ops buffer returned — not $500k)
- Bills: `0x01D1De8796B1dDbdB5C900277A54b6944C125906`
- Unwind tx: `0x704afa3365e21a76ffc69b484f7998cb803495b3ba44abcb8d06fb9a4109cb63`

## Order
1. Move **yELE** Landing → Hot (one transfer) — **done by King**
2. Fire unwind (no loop) — **done**
3. Books clean · Elepan free · surplus USDC → Landing — **done**
4. Then Morpho-right borrow → Landing **KEEP** when idle exists (no yELE recycle)

## Why yELE must sit on Hot
Landing held the vault shares that were the ~$14M USDC. Hot key cannot redeem Landing’s shares without that transfer/approve. MetaMorpho blocks owner skim/reallocate-out.

## Fire
```bash
KING_GO=1 FIRE_ELE_BILLS=1 BILLS=0x01D1De8796B1dDbdB5C900277A54b6944C125906 \
  forge script script/FireElepanBills.s.sol:FireElepanBills \
  --rpc-url $BASE_RPC --broadcast --slow
```

## Fork
`ElepanBillsLiveBuf` / `ElepanBillsForkTest` — debt 0, coll 0 with live ~$5.65 buffer once all yELE on hot.

## Truth on $500k
Matched self-loop cannot mint net $500k out of thin air. Unwind cleaned the bad loan. Spendable $500k = Morpho borrow KEEP after real idle (or matcher). No recycle. Landing USDC is **~$5.65**, not $500k.
