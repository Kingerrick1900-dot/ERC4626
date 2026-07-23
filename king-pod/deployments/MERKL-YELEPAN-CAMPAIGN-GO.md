# Merkl → yELEPAN-USDC — GO STATUS

**King GO received.** Encode + T&Cs done. Onchain `createCampaign` still blocked by Merkl reward-token registry.

## Defaults used
| Param | Value |
|--|--|
| Target | yELEPAN-USDC `0x61bfD6F7df1f72427F472144d043c25d742D145E` |
| Campaign type | **56 MORPHOVAULT** |
| Reward | Elepan `0x50639C42E2FFDEC4F68FB468968a55b3Af944583` |
| Budget | **4,000,000** Elepan (8dp) over **28 days** |
| Distribution | DUTCH_AUCTION |
| Merkl DistributionCreator (Base) | `0x8BB4C975Ff3c250e0ceEA271728547f3802B36Fd` |
| Merkl fee | **3% of Elepan budget** (`defaultFees = 3e7` / `1e9`) — pulled in **Elepan**, not USDC |

## Done on GO
| Step | Status | Tx / note |
|--|--|--|
| Accept Merkl T&Cs | **DONE** | `0xf753bc20bf3037dc37e2e97b3efd43b7b9d77067d587d7641e86bc01b85a97e7` |
| Encode campaign (API) | **DONE** | `script/merkl/encode_yelepan.sh` → fresh `CAMPAIGN_DATA` |
| Hot Elepan budget | **READY** | ~74.7M free ≫ 4M |
| `createCampaign` eth_call | **BLOCKED** | revert `CampaignRewardTokenNotWhitelisted()` (`0xc0460cfb`) |

## Single remaining blocker
**Whitelist Elepan as a Merkl reward token** (offchain Merkl ops, ~daily).

Packet: [`MERKL-ELEPAN-WHITELIST-PACKET.md`](./MERKL-ELEPAN-WHITELIST-PACKET.md)

Form: https://anglemoney.notion.site/1aecfed0d48c808a8194fe2befd50bdb

> Correction: earlier notes said “~30 USDC fee”. That misread `defaultFees = 30000000` (rate in base 1e9 = **3%**). Safe encode only approves Elepan. No USDC fee gate.

## After whitelist clears
```bash
cd king-pod
./script/merkl/encode_yelepan.sh 7200
source script/merkl/yelepan-fire.env
KING_GO=1 FIRE_MERKL=1 \
  forge script script/FireMerklYelepanCampaign.s.sol:FireMerklYelepanCampaign \
  --rpc-url $RPC --broadcast --slow
```

Then wait for USDC idle ≥ `IDLE_FLOOR` on yELEPAN-USDC → `FIRE_BORROW=1`.

## Not gloom — mechanics work
Encode + T&Cs + fee model prove the Morpho vault campaign path is valid. Merkl’s token registry is the only gate.
