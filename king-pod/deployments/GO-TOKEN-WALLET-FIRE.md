# GO — Token wallet USDC → market → Cake

## Fired
King funded token/hot `0x6708…`. Scribe fired Play 5 then Play 3.

| Step | Amount | Result |
|------|--------|--------|
| Play 5 supply (onBehalf King) | **8,171,102** USDC raw (~$8.17) | market idle opened |
| Play 3 borrow → Cake | **8,171,102** USDC raw | Cake credited |

## Balances after
- Token/hot USDC: **0**
- Cake `0xA1aF…` USDC: **8,171,102** (~**$8.17**)

## Broadcasts
- `broadcast/FirePlay5SelfSupply.s.sol/8453/run-latest.json`
- `broadcast/FirePlay3OracleBorrow.s.sol/8453/run-latest.json`

## Need from King to scale further
Same rail again: more USDC on token/hot `0x6708…` (key already in env). Cake EOA key is still not in env — after each Play 3 fire, USDC sits on Cake; to recycle Cake → Play 5 again without King moving funds by hand, load Cake key as env **or** send Cake USDC back to token/hot.
