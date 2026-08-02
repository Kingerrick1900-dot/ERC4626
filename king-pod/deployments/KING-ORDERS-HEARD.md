# King Orders — Heard & Status

## 1) \$700k to King wallet for minted asset
- Minted asset: **kUSD** via CDP (1M RSS → 700k kUSD) — live
- Settlement door: **CrownZkAdvance** `0xD36a…035B` — USDC in → **Landing** `0x5Adcea…2357`, kUSD out
- Status: door + ZK live. **Execution of \$700k USDC settle needs funded advance.**

## 2) Bring back fees — FIRED
- yRSS fee recipient: **Landing** (confirmed)
- `FireHarvestSpoils` broadcast — fee rail pointed Landing; dust above floor swept
- Broadcast: `broadcast/FireHarvestSpoils.s.sol/8453/run-latest.json`

## 3) Cross-chain — ARMED
- Script: `FireCctpBridgeUsdc.s.sol` — Base USDC → Ethereum via Circle CCTP V2
- Mint recipient default: Landing (same addr on ETH)
- Fires only with `KING_OK=1 KING_GO=1 FIRE_CCTP=1 AMT=...` (min \$1 — no dust)
- When Landing/hot holds real USDC size: **KING GO** bridges to ETH for bills/bank rails

No unauthorized maximizes. Only ordered fires.
