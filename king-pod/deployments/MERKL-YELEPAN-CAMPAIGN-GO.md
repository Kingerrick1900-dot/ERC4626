# Merkl → yELEPAN-USDC — OPTIONAL PARALLEL (not critical path)

**Doctrine:** Merkl is an emissions amp on top of Kingdom rails.  
Protocol scale = `KINGDOM-PROTOCOL-SCALE.md` (P0 convert + P1 own-curator credit).  
**Nothing live without King `KING_GO=1` + `FIRE_MERKL=1`.**

## Defaults (if King ever fires this amp)
| Param | Value |
|--|--|
| Target | yELEPAN-USDC `0x61bfD6F7df1f72427F472144d043c25d742D145E` |
| Type | 56 MORPHOVAULT |
| Reward | Elepan `0x50639C42…4583` |
| Budget | 4,000,000 Elepan / 28 days · DUTCH_AUCTION |
| Creator | `0x8BB4C975Ff3c250e0ceEA271728547f3802B36Fd` |
| Fee | **3% of Elepan** (`defaultFees = 3e7 / 1e9`) — not USDC |

## Ready
| Step | Status |
|--|--|
| T&Cs | DONE · `0xf753bc20…` |
| Encode helper | `script/merkl/encode_yelepan.sh` |
| Fire script | `FireMerklYelepanCampaign.s.sol` (whitelist precheck) |
| Hot budget | ~74.7M Elepan ≫ 4M |

## External gate (does not block protocol)
Elepan `rewardTokenMinAmounts == 0` → `CampaignRewardTokenNotWhitelisted()`.  
Packet: `MERKL-ELEPAN-WHITELIST-PACKET.md` — submit only if King wants this amp.

## Fire (King only)
```bash
cd king-pod
./script/merkl/encode_yelepan.sh 7200
source script/merkl/yelepan-fire.env
KING_GO=1 FIRE_MERKL=1 \
  forge script script/FireMerklYelepanCampaign.s.sol:FireMerklYelepanCampaign \
  --rpc-url $RPC --broadcast --slow
```
