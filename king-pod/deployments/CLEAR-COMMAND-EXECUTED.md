# King clear command — EXECUTED (partial)

**Order:** 100k eUSD hot → completer → USDC → bridge Base Landing. No builds.

## Fired

| Step | Result |
|--|--|
| Completer | **LIVE** — King as matcher |
| Amount | **527,777** raw USDC (~**$0.53**) — all Scroll hot USDC |
| Approve | `0x2aabf8a1e81f9a3dbe42117e4ea367bab38de945fdb5c2ee4337be2a1e613ffb` |
| `complete` | [`0xd47f3137c35abaa982d42981af9430744aa8200ebba88e030cca717e9e115c02`](https://scrollscan.com/tx/0xd47f3137c35abaa982d42981af9430744aa8200ebba88e030cca717e9e115c02) |
| Scroll Landing USDC | **527,777** |

## 100k eUSD — not consumed

Live completer `0x2cf08F81…66f6` pulls **matcher USDC only**. It does **not** burn or take eUSD.

| Wallet | eUSD after |
|--|--|
| Scroll hot | still **~100,001 eUSD** |

Pool eUSD/USDC depth remains **~$0.20**. No live PSM USDC reserves for 100k redeem. Bridge Base Landing of the $0.53 is below ops need; CCTP Scroll→Base not fired this turn (no armed reverse script + dust size).

## Truth to crown

Completer obeyed with every USDC wei on hot. The 100k eUSD clear cannot exit through this completer — wrong machine for eUSD. Asset still on hot.
