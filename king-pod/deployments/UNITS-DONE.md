# ALL UNITS — status pack

## Unit A — Trace (DONE)
File: `deployments/rss-liquid-trace.json`

King RSS outflows (who got tokens):
- `0x4aa7…2dcc` (King-owned) — **~20.979B** then **0** now → routed onward (mint/pair path)
- MorphoKingDesk `0x831b…2472` — **82.5M** (now **0** — moved through desk)
- CrownFlashOpen `0x15F9…2A7d` — **18.2M** (now **0**)
- V2 pair `0xfD87…774B` — **~1.57M**
- KingRssSale — **227k**
- V2 pod — **227k**
- Elite flash closer — **~7.8k** across many txs
- Desk fills / elite close — smaller

**Live balances now:** V1 pair **~20.981B**, King hot **~18.49M**, desk **~5.5k**. Supply fully accounted.

## Unit B — Stop bleed + desk rescue (SCRIPTS READY)
- `script/kill-fire.sh` — do not run fire-duty / elite auto close
- `script/RescueDeskRss.s.sol` — pull desk RSS → King  
  Run on greenlight: `forge script script/RescueDeskRss.s.sol:RescueDeskRss --rpc-url $BASE_RPC --broadcast`

## Unit C — Oracle $1 + max yRSS + PA wire (SCRIPT READY)
- `script/ArmYrssPipe.s.sol`  
  Sets oracle **$1**, yRSS cap **$14M**, Public Allocator on yRSS, flow caps on RSS market.  
  Run on greenlight: `forge script script/ArmYrssPipe.s.sol:ArmYrssPipe --rpc-url $BASE_RPC --broadcast`

## Unit D — Curator listing (PACKET READY)
- `deployments/CURATOR-LISTING-PACKET.md`  
  Gauntlet + Steakhouse vaults, market params, requested **$700k maxIn**.

## Unit E — Borrow fire (SCRIPT READY, gated)
- `script/FireReallocateBorrow.s.sol`  
  Post RSS + borrow → KingVault when market has liquidity / PA path live.  
  Env: `PA_VAULT`, `BORROW_USDC`, `RSS_COLLATERAL`, `PRIVATE_KEY`.

## Broadcast rule
All broadcast scripts **parked until King greenlight**. Artifacts are ready.
