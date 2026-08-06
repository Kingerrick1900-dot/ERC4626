# King rest sheet — mission status

## Plan (simple)
1. Make Morpho **see** idle  
2. Morpho **loans** that amount  
3. Loan lands on **Landing** and **stays** → **$700k USDC**

## Done
- Live broadcast: Morpho saw **$1M** idle, loaned **$1M** (scribe on `0x68F4…8866`)
- Fork: Landing **+$1M** and **+$700k** paths **PASS**

## Ready (not fired live yet)
```bash
# Only when hot holds ASK USDC to close the flash cleanly:
FIRE=1 TO_LANDING=1 ASK=700000000000 \
  forge script script/FireIdleBroadcast.s.sol:FireIdleBroadcast \
  --rpc-url $BASE_RPC_URL --broadcast --slow
```
Seeder: `0x68F439486E72765e2CA019FE2a55038090bd8866`

## Board now
- Landing USDC ~**$2.41**
- Idle ~**1 wei**
- Proof on-chain: **yes**

Chief holds live Landing fire until close capital = **$700k USDC** is on hot (same settle the Morpho loan broadcast needs). Fork is sure. Rest.
