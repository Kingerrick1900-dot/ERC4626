# FREEZE — World-domination audit: “$10M One Rail Three Adapters”

**Mode:** FREEZE · audit only · **do not deploy / do not canary**  
**Plain verdict:** Architecture cosplay. The money pipe is imaginary.

---

## Executive kill (a16z diligence)

| Claim | Audit |
|--|--|
| `psp.swapEUsdForUsdc` 1:1 | **No production PSP.** Kingdom eUSD (`Kingdom Elepan USD`) is mint/optics. Prior probe: eUSD **NotListed** on multi-PSM; eUSD→USDC DEX **dust**. `maxSwap()` on empty USDC = **0**. Rail never leaves chunk 0. |
| `$10M` fire sizing | HOT free eUSD ~**$2.45M** + Landing ~**$2M** ≈ **$4.45M** liquid eUSD — not $10M without **more mint**. Mint ≠ USDC. |
| Flashbots Protect | `https://rpc.flashbots.net` → **chainId 1 (Ethereum)**. Base is **not** that mempool. Cast-to-Flashbots from Base keys = wrong chain / fail. Base MEV = sequencer; use private relays that actually support **8453**, or accept public Base. |
| `cast … --private-key $SAFE_PK1` + 2/3 Safe | **Contradicts 2/3.** One owner key is not the Safe. Real path: Safe tx proposal → 2 confirmations → exec. Checklist item is theater. |
| Aero USDC→WETH→cbBTC @ 0.5%×2 | Worse than direct Uni **USDC/cbBTC 500** (live deep). Compound slip ~1% before impact. No pool-depth quote at $3.33M. |
| “~126 cbBTC = ~$9.6M lasting” | Swapping $10M USDC→BTC yields BTC **inventory**, not Morpho **unmatched USDC idle**. Lasting park idle needs **supply USDC** or **asymmetric L2** (already: KingRail P4 / CbbtcIdlePuller). Locking cbBTC alone ≠ idle. |
| “Real APY 65% on Locking” | **Undefined.** Not a Morpho market parameter we run. Marketing number. |
| Fork block `22000000` | Base head ~**51M**. Stale fork = wrong liquidity. |
| Grafana `psp.usdc ≥ eusdSupply×0.99` | Ocean minted eUSD/gUSD is **billions**. Invariant can never hold. Pause forever or never alert usefully. |
| Replaces live crown stack | Ignores armed **CrownKingRail** + **CbbtcIdlePuller**. Greenfield rewrite without PSP reserves = zero delta. |

**Seat line:** Adapters without a **USDC-funded** redeem rail are a prettier `revert`.

---

## What would make this real (still freeze)

1. **Name the USDC source** for PSP/PSM (≥ canary, then scale) — treasury, market maker, inbound LP — not eUSD mint.  
2. **List + seed** eUSD on that PSM with **Circle USDC reserves** (or drop PSP and require USDC in).  
3. Wire adapters to **existing** rail/puller — or prove why replace.  
4. Safe: real **8453** multisig flow; no single-PK “Safe”.  
5. Swap: quote **direct** USDC→cbBTC; chunk by **impact**, not vibes.  
6. Define Locking = Morpho `supplyCollateral` + optional P4 idle engineer — measure **park idle**, not “locked BTC APY.”  
7. Fork at **current** Base head; canary **$1k–$10k** not $100k until PSP `maxSwap` ≥ chunk.  

---

## Canary now?

**No.** Canary presupposes `psp.swapEUsdForUsdc` pays Circle USDC. It does not exist at size. Firing is a failed cast or a rug of kingdom eUSD into dust DEX.

Lift freeze only when: PSM/PSP USDC reserves **≥ canary**, signer path is Safe-on-Base, and success metric is **USDC or cbBTC on HOT / park idle** — not adapter line counts.
