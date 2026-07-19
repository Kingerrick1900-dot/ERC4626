# Airtight layer — theft / MEV / custom-code failure

No paid audit yet. This is the practical harden stack.

## Honest threat model

| Threat | Real on our path? | Mitigation |
|--------|-------------------|------------|
| Classic sandwich (DEX) | **Low** — no swap in ATTACK/FEED | Path is Morpho flash + vault + borrow only |
| Frontrun steal of flash USDC | **No** — flash is atomic in one tx | Callback all-or-nothing |
| Grief ATTACK so it reverts | Possible (noise) | Retry; you lose gas only, not funds |
| Copy strategy after success | Possible | Not theft of your bag |
| Custom seeder bug | Main residual | Invariants + ladder + thin wrapper |
| Stolen/exposed hot key | **Highest real theft risk** | Rotate hot before $9M; never paste landing seed |
| Phishing / bad signature on landing | High if used | Landing cold — never connect dapps |

Base uses a **central sequencer** (not ETH public mempool Flashbots). Prefer a **private/paid RPC** for broadcast. Still: atomicity is the real shield for this path.

## Code hardenings (done)

1. **Atomic flash** — RSS post + vault deposit + borrow inside one Morpho flash  
2. **End-of-callback invariants** — vault assets, debt, flash repay balance must match or full revert  
3. **Recoverer** — repay + free RSS if needed  
4. **Preflight** — `PreflightWarElephant.s.sol` prints `READY=1` or `READY=0`  
5. **Ladder** — micro live before $9M  

## Ops airtight checklist (King before go)

1. **Rotate hot** if this key was ever in chat/agents → new hot, move RSS, re-PREP auth  
2. **Landing** never connected to a site; seed never pasted  
3. Top up hot **≥ 0.02 ETH**  
4. PREP seeder + recoverer; record addresses  
5. `forge script script/PreflightWarElephant.s.sol --rpc-url $RPC` → must `READY=1`  
6. Fork-sim ATTACK at exact size (no broadcast)  
7. Live micro ATTACK + FEED ($1k)  
8. Broadcast $9M via **private/paid Base RPC** if available  
9. One tx at a time if EIP-7702 / in-flight limits bite (`cast send` sequential)  
10. After ATTACK: verify vault shares + Morpho debt on Basescan before FEED  

## Preflight command

```bash
SEEDER=0x... RECOVERER=0x... BORROW_USDC=9000000000000 \
  forge script script/PreflightWarElephant.s.sol --rpc-url $RPC -vv
```

Expect: `READY=1`

## What we are NOT claiming

- Not a substitute for a professional audit  
- Not invisible to the Base sequencer  
- Not “unstealable” if the hot key is compromised  

We **are** claiming: no mid-flash fund drop, fail-closed invariants, recover path, and low MEV surface because there is no DEX leg.
