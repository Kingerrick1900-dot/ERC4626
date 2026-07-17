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
| Off-peak | `OFFPEAK_ONLY=1` waits for Sat/Sun UTC or 04:00–12:00 UTC |
| Elixir / USDC gas | Circle-style paymaster (AA) shields ETH volatility — future rail; EOA loop still pays tiny ETH |
| Exact fuel | ~200k gas ≈ $0.002 on Base; hot holds ~0.002 ETH — enough for many laps |

If a step OOGs, it reverts; retry with a smaller step. **Do not raise the gasLimit theater.**

## Run
```bash
export LOOP_PRIVATE_KEY=...   # loop wallet key (never commit)
export PRIVATE_KEY=...        # King hot
export MAX_LOOPS=20
export MIN_USDC=100000        # stop under $0.10
export HARD_GAS_CAP=350000    # per-step budget ceiling
# export OFFPEAK_ONLY=1       # optional quiet-window gate
python3 script/king_loop.py
```

## Notes
- Cake stays kingdom trough / receive for final spoils; loop wallet keeps the cycle alive.
- Each lap adds PoD supply (via yRSS) + King borrow while recycling the same USDC.
- Stops on low hot USDC, gas floor, or max loops.
- Fleet stays untouched unless King orders otherwise.
- Prefer `LOOP_SEND_RPC` / `BASE_RPC_URL` over public `mainnet.base.org` (429 + stale idle=0 can strand a lap mid-PA). Idle is re-read with retries after PA.
