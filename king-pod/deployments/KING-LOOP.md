# King Loop — automated (proven rails)

## Play
Not new Morpho physics. Driver around live rails:

1. Hot USDC → yRSS deposit  
2. PA `reallocateTo` yRSS cbBTC → RSS  
3. Morpho borrow idle → **loop wallet** `0x8d3cfbFc6A276f118579517E4d166e94C66F8585`  
4. Loop USDC → Hot (recycle)  
5. Repeat

## Gas discipline (King)
Base is cheap. Failures come from **one tx trying to do too much**, or from a **gasLimit budget larger than the wallet can preflight**.

| Rule | How the script obeys |
| --- | --- |
| Split the loop | Approve / deposit / PA / borrow / recycle = **five txs** |
| callStatic + estimate | Dry-run then `estimateGas` before send |
| Cap the limit | `gasLimit = min(est + buffer, HARD_GAS_CAP, walletAffordable)` — budget, not requirement |
| Multi-RPC | Rotate on 429/throttle across free + keyed endpoints (per-endpoint limits) |
| Off-peak | `OFFPEAK_ONLY=1` waits for Sat/Sun UTC or 04:00–12:00 UTC |
| Elixir / USDC gas | Circle-style paymaster (AA) shields ETH volatility — future rail; EOA loop still pays tiny ETH |
| Exact fuel | ~200k gas ≈ $0.002 on Base; hot holds ~0.002 ETH — enough for many laps |

If a step OOGs, it reverts; retry with a smaller step. **Do not raise the gasLimit theater.**

## Multi-RPC failover (the 429 fix)
Rate limits are **per endpoint**, not per wallet. `RpcPool` swaps the Web3 provider mid-run on 429/5xx/timeouts.

Built-in free pool (no key):
- `https://base-rpc.publicnode.com`
- `https://base.publicnode.com`
- `https://base-mainnet.public.blastapi.io`
- `https://base.meowrpc.com`
- `https://base.drpc.org`
- `https://base.gateway.tenderly.co`
- `https://developer-access-mainnet.base.org`
- `https://mainnet.base.org`

Optional keyed (env):
- `ALCHEMY_API_KEY` → Alchemy Base
- `ANKR_API_KEY` → Ankr
- `PINAX_API_KEY` → Pinax
- `BLOCKPI_API_KEY` → BlockPI Base
- `QUICKNODE_BASE_RPC` → QuickNode / x402 URL
- `BASE_RPC_URLS=url1,url2,...` → custom ordered list
- `/tmp/loop_rpc.txt` or `LOOP_SEND_RPC` / `RSS_RPC_URL` preferred first

## Run (manual batch)
```bash
export LOOP_PRIVATE_KEY=...   # loop wallet key (never commit)
export PRIVATE_KEY=...        # King hot
# optional: export ALCHEMY_API_KEY=...
export MAX_LOOPS=20
export MIN_USDC=100000        # stop under $0.10
export HARD_GAS_CAP=350000    # per-step budget ceiling
python3 script/king_loop.py
```

## Run (automatic — no hand on the tiller)
```bash
export LOOP_PRIVATE_KEY=...
export PRIVATE_KEY=...
export AUTO_RESTART=1
export MAX_LOOPS=50
export RESTART_SLEEP=45
bash script/king_loop_auto.sh
```
Stops only on USDC/gas floor; otherwise sleeps `RESTART_SLEEP` and fires the next batch.

## Notes
- Cake stays kingdom trough / receive for final spoils; loop wallet keeps the cycle alive.
- Each lap adds PoD supply (via yRSS) + King borrow while recycling the same USDC.
- Stops on low hot USDC, gas floor, or max loops.
- Fleet stays untouched unless King orders otherwise.
- Idle is re-read with retries after PA; recycle waits for hot USDC to settle before the next lap.
