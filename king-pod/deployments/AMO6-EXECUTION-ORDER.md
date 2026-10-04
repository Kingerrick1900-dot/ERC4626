# AMO 6 → AMO 1 — Execution Order

## Phase A — Armor (now)

1. Audit `CrownCircuitBreaker` · `ColdBufferLaw` · `MintGate`  
2. King/KAR: `FIRE_AMO6=1` deploy  
3. `setMinBufferBps(3000)` on live ColdBuffer (script does if < 3000)  
4. `registerAMO` every pausable AMO on breaker  
5. Set `yRssBaseline = yRSS.totalAssets()`  
6. Confirm `MintGate.canMint() == false`  
7. Publish breaker + gate addresses + attest epochs to scoreboard  

**Exit:** checklist rows 4–6 green.

## Phase B — External legs (only after A)

1. TWAMM fills / Route A sweeps → HOT USDC  
2. Seed Ocean **USDC** leg via DeepPull (named destination)  
3. Add USDT · DAI · EURC  
4. Only then AMO 2–5  

## Phase C — Parallel (does not unlock capital)

- QKD pilot / Dilithium·Kyber on AMO txs  
- China / AxCNH — King signature  
- V1 20.98B RSS migrate or burn before scale  
- FlashBleed stays reference-only  

```
GATE=AMO6_green
NEXT=Ocean_external_USDC
FIRE=FIRE_AMO6=1_then_King
```
