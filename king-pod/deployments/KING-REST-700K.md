# King rest sheet — mission status

## Plan (simple)
1. Make Morpho **see** idle  
2. Morpho **loans** that amount  
3. Loan lands on **Landing** and **stays** → **$700k USDC**

## Done
- Live broadcast: Morpho saw **$1M** idle, loaned **$1M** (scribe on `0x68F4…8866`)
- Fork: Landing **+$1M** and **+$700k** paths **PASS**

## Ready (Seamless close — zero hot USDC buffer)
```bash
forge test --match-contract SeamlessMissionFork -vv --fork-url $BASE_RPC_URL
```
Live Landing fire only when Seamless surplus path shows Landing Delta = ask (foreign/PA idle).
Seeder (prior rematch proof): `0x68F439486E72765e2CA019FE2a55038090bd8866`

## Board now
- Landing USDC ~**$2.41**
- Idle ~**1 wei**
- Proof on-chain: **yes**

Close is **Seamless-engineered** (debt on router repays flash) — not a hot USDC buffer.  
Landing +$700k = Seamless **surplus** once foreign/PA idle exists. See `PROTOCOL-COMPLETE-CLOSE.md`. Rest.
