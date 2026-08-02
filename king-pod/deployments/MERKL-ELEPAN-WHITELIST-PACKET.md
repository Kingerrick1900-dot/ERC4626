# Merkl reward-token whitelist — Elepan (RSS)

`createCampaign` reverts `CampaignRewardTokenNotWhitelisted()` until Merkl sets
`rewardTokenMinAmounts(Elepan) > 0` on DistributionCreator
`0x8BB4C975Ff3c250e0ceEA271728547f3802B36Fd` (Base).

Merkl processes whitelist requests ~once/day via:
https://anglemoney.notion.site/1aecfed0d48c808a8194fe2befd50bdb

## Form fields (copy/paste)

| Field | Value |
|--|--|
| Chain | Base (`8453`) |
| Token address | `0x50639C42E2FFDEC4F68FB468968a55b3Af944583` |
| Name | `elephanToken` |
| Symbol | `RSS` (onchain); display **Elepan** |
| Decimals | `8` |
| Soft price | **$1.00** (Kingdom soft peg) |
| Price source | Morpho moat oracle (fixed 1e34 Elepan/USDC): `0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19` |
| Basescan token | https://basescan.org/token/0x50639C42E2FFDEC4F68FB468968a55b3Af944583 |
| Basescan oracle | https://basescan.org/address/0xe290B586FAa8A2cC219edFEb202bf1E6ec64cf19 |
| Campaign intent | MORPHOVAULT type 56 → yELEPAN-USDC `0x61bfD6F7df1f72427F472144d043c25d742D145E` |
| Budget (planned) | 4,000,000 Elepan over 28 days (~$5.95/hour at $1 soft) |
| Contact wallet | Hot `0x6708e21113922ED588bBCcAA5ef756BEcBb2a7d1` |
| Contact email | efrthompson008@gmail.com |

## Verify whitelist cleared

```bash
cast call 0x8BB4C975Ff3c250e0ceEA271728547f3802B36Fd \
  "rewardTokenMinAmounts(address)(uint256)" \
  0x50639C42E2FFDEC4F68FB468968a55b3Af944583 \
  --rpc-url https://mainnet.base.org
# must be > 0
```

## Then fire

```bash
cd king-pod
./script/merkl/encode_yelepan.sh 7200
source script/merkl/yelepan-fire.env
KING_GO=1 FIRE_MERKL=1 forge script script/FireMerklYelepanCampaign.s.sol:FireMerklYelepanCampaign \
  --rpc-url $RPC --broadcast --slow
```
