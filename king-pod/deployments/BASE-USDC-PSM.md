# Base USDC PSM — LIVE

**Order:** Deploy Base USDC PSM → seed USDC → then scale external CDP mint.  
**Play:** Zero-slippage eUSD ↔ USDC on Base. Unblocks external coll mint without crushing the ELE/eUSD pool.

| | |
|--|--|
| **PSM** | [`0xfFEd7981f924Edc652E9b767aCa601505dfa4977`](https://basescan.org/address/0xfFEd7981f924Edc652E9b767aCa601505dfa4977) |
| Contract | `src/CrownBaseUsdcPsm.sol` |
| eUSD | `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a` (18dp) |
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` (6dp) |
| Peg | 1 eUSD ↔ 1 USDC · `feeBps=0` |
| Minter | **YES** on eUSD |
| Reserve | **139311** USDC (6dp) ≈ **$0.139** WIRE seed |

## Legs

| Call | Direction | Effect |
|------|-----------|--------|
| `mint(usdc, to)` | USDC → eUSD | Mints eUSD; USDC stays as redeem reserve |
| `redeem(eusd, to)` | eUSD → USDC | Burns eUSD; pays USDC from reserve |
| `seedUsdc(amt)` | King only | Capitalize redeem floor (explicit amt) |

## vs inventory PSM

Older inventory clear [`0x9199E509…060b`](https://basescan.org/address/0x9199E5099C2C46A688F982E377a146Ab6db8060b) holds eUSD inventory — does **not** mint. This module is the Maker rail.

## Txs

| Step | Hash |
|--|--|
| Deploy PSM | [`0x221022cd…baff`](https://basescan.org/tx/0x221022cd4280b601c5aab9bde1496dde00fc5705fa78f25f0bcc9c43cc42baff) |
| `setMinter(psm, true)` | [`0xef70d6d1…9c6a`](https://basescan.org/tx/0xef70d6d17921df8eef9c2a4ebe6b1c8346f99f5c4dd852882f991021abd29c6a) |
| Approve + `seedUsdc(139311)` | [`0xdc2ea6e7…37b2`](https://basescan.org/tx/0xdc2ea6e7722db7713823dc7d752fc4a24d5ad0729c73ff5976fed404d1fd37b2) / [`0xdb47ead6…9236`](https://basescan.org/tx/0xdb47ead60b112e13ec5d0f73809b3eb099fba9acf394d2aa61df8125ff8a9236) |

Broadcast: `king-pod/broadcast/FireBaseUsdcPsm.s.sol/8453/`  
Fork tests: `BaseUsdcPsmForkTest` **3/3 PASS**  
Status: `BASE_USDC_PSM_OK`

## Capitalize next

WIRE seed proves the rail. Peg floor that can absorb WETH/cbBTC mint needs **real USDC inflows** into `seedUsdc` before debt limits scale. Empty theater ≠ peg.

```bash
KING_GO=1 FIRE_BASE_USDC_PSM=1 PSM=0xfFEd7981f924Edc652E9b767aCa601505dfa4977 \
  SET_MINTER=0 SEED_USDC_AMT=<explicit_6dp> \
forge script script/FireBaseUsdcPsm.s.sol:FireBaseUsdcPsm \
  --rpc-url "$RPC_URL" --broadcast --slow --private-key "$PRIVATE_KEY"
```
