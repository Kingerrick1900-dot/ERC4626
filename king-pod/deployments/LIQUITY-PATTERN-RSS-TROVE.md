# Liquity-pattern RSS Trove → eUSD mint

**Status: LIVE on Base.** Morpho untouched. Landing eUSD ~**$700k**.

## Doctrine

1. Morpho RSS market = demand signal, not ops cash. Book stays.
2. Free RSS on hot is CDP collateral.
3. Mint Kingdom eUSD to Landing — no pooled lenders, no idle USDC wait.

## Live

| Item | Value |
|--|--|
| **Trove** | `0xC499bbD936Ba012fd77e8494a955D62e95503fFD` |
| Deploy tx | `0xe0f1feba5e3553a6512507d2e480a8fef32757c42b6a84abbc8b714bbfd39d34` |
| Open/mint tx | `0x7e6765a7378080512ec6e315d0f0c232cf6ca5b402c5580b55bd29771f6e6621` |
| Coll locked | ~519.48 RSS |
| Minted | **400,000 eUSD** → Landing |
| Landing eUSD | **~700,027** |
| Morpho RSS coll (hot) | **220,000** (unchanged) |

## Chassis

| Item | Value |
|--|--|
| Contract | `CrownRssTrove` |
| Collateral | RSS `0x7a305D07B537359cf468eAea9bb176E5308bC337` |
| Debt | Kingdom eUSD `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a` |
| Oracle | Morpho RSS/$1200 `0xB5840644142B341a6145335e2ebc82EEBC7aE1B9` |
| LTV | 77% (WAD) |
| Self-set rate | 5% (stored; Liquity V2 pattern) |
| Debt ceiling | 1,000,000 eUSD |
| King / Landing | hot / landing |

## Full Liquity V2 bold note

Upstream `liquity/bold` is BUSL — commercial deploy needs Liquity AG friendly-fork license. Base friendly fork (BaseDollar) is separate. This chassis ships the **same move** (isolated Trove, mint stable vs free RSS) on Kingdom rails now. Full bold branch + RSS PriceFeed can follow license.

## Fire

```bash
# fork prove
forge test --match-contract RssTroveMintFork --fork-url $BASE_RPC_URL -vv

# live (default mint 400_000 eUSD → Landing ~700k with existing ~300k)
forge script script/FireRssTroveMint.s.sol:FireRssTroveMint \
  --rpc-url $BASE_RPC_URL --broadcast -vvvv
```

Env overrides: `MINT_EUSD`, `COLL_RSS`.

## Size

| Pull | Mint | Landing eUSD (approx) |
|--|--|--|
| Existing | — | ~300k |
| First fire | 400k | ~700k |
