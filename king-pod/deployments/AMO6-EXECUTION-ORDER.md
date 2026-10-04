# AMO 6 → AMO 1 — Execution Order

**Now:** code built in PR #194. Connections **not** live. Waiting on King AMO 6 fire.

## Phase 1 — Armor fire (blocked on King/KAR)

1. Audit `CrownCircuitBreaker` · `ColdBufferLaw` · `MintGate`  
2. King/KAR: `FIRE_AMO6=1` deploy  
3. `setMinBufferBps(3000)` on live ColdBuffer (script does if < 3000)  
4. `registerAMO` every pausable AMO on breaker  
5. Set `yRssBaseline = yRSS.totalAssets()`  
6. Confirm `MintGate.canMint() == false`  
7. Publish breaker + gate addresses + attest epochs to scoreboard  

**Exit:** AMO 6 checklist green on-chain (kill switch armed · Cold 30% · mint locked).

## Phase 2 — Spoils router (only after Phase 1 green)

1. `FIRE_SPOILS=1` → deploy `CrownSpoilsOfWar`  
2. Point `oceanExternal` at DeepPull / Ocean USDC sink  
3. Route A/B fills may call `takeSpoil` — still no Ocean seed required yet  

## Phase 3 — External legs / AMO 1 (only after Phase 1 green)

1. TWAMM fills / Route A → HOT USDC (and/or spoils split)  
2. Seed Ocean **USDC** leg via DeepPull — **first** external connection  
3. Add USDT · DAI · EURC  
4. Only then AMO 2–5  

**Not done:** no USDT/DAI/USDC/EURC seeded into Ocean. Phase 3 has not fired.

## Parallel (does not unlock capital)

- QKD pilot / Dilithium·Kyber on AMO txs  
- China / AxCNH — King signature  
- V1 20.98B RSS migrate or burn before scale  
- FlashBleed stays reference-only  

```
STATE=built_not_connected
GATE=AMO6_green
PHASE3=Ocean_external_USDT|DAI|USDC|EURC
FIRE_NOW=none_until_King_FIRE_AMO6=1
```
