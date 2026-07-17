# KINGDOM ACTION PLAN — DeepSeek × Grok × Chief Engineer

## Verdict
Both AI plans point at the same wall: the realloc source is empty. Neither invents free USDC. The Crown already owns the levers (oracle $1, PoD ~$9.25M at 100% util, PA maxIn $700k on yRSS, SpoilFire, CrossFlash with repayRail = King hot). The job now is fund the source and fire the bundle — not redesign the building.

## What each plan got right
DeepSeek is correct that Peapods-style PoD, yRSS as the pipe, PA reallocateTo + borrow, and KingVault as the trough are the industry path. Grok is correct that direct access and a flash bridge are practical when the source is thin. Oracle at $1 is already live — that lever is not missing.

## What must be corrected so we do not ship nonsense
Cake is receive-only. Do not build “King pulls from Cake.” That burns gas and violates the vault design. yRSS cannot pull USDC from Gauntlet or Steakhouse cbBTC/WETH books until those vaults enable RSS and set maxIn. Allocating “from those books into yRSS” without a deposit into yRSS is empty talk. A Morpho flash does not leave hard USDC in Cake unless a separate repay rail covers the flash. CrossFlash already encodes that: supply on sink, borrow to Cake, repay from repayRail — not from Cake.

## The action plan (engineer owns execution)

Phase A — Hold the position signal. Keep oracle at $1. Keep PoD book at full util. Do not unwind the $9.25M book for optics. Quiet scaler stays. This is the magnet DeepSeek named.

Phase B — Fund the source pool we control. yRSS totalAssets is dust. Any USDC the Kingdom allocates into the pipe goes: King hot → deposit yRSS → yRSS holds depth on cbBTC/WETH/RSS queue. That is curator-bank behavior on our own vault. Size is whatever hot holds plus whatever the King wires to hot. No Cake outbound. No foreign maxIn required for this phase.

Phase C — Fire the Morpho elite bundle on our pipe. Once yRSS has real USDC on a source market with maxOut, call Public Allocator reallocateTo into RSS, then borrow against the PoD to Cake in one flow (SpoilFire / FirePositionSeed700k). Seed is output of the position. Cake receives. Debt holds.

Phase D — CrossFlash bridge when repayRail is funded. Grok’s flash bridge maps to CrownCrossFlash already deployed. repayRail is King hot. When hot has sized USDC approved to CrossFlash, fire: flash Morpho float → supply sink → borrow to Cake → repay flash from hot. Cake keeps the borrow. Hot pays the flash. That is loan plus token without waiting on Gauntlet.

Phase E — Foreign PA as amplifier, not the engine. Curator packet stays live for Steakhouse and Gauntlet. When they enable RSS maxIn, the same bundle scales to $700k without redesign. Listing is broadcast of the engineered position, not a wait chair for Phase B–D.

Phase F — Fill the trough continuously. Strike on HF under 1 when sized and covered. Router fees and yRSS performance fee already point at Cake. Every profitable fire sweeps Cake. No new trough contract.

## Order of fire (no peasant wait)
First: Phase B with whatever USDC sits on hot (and any further wire to hot the King chooses). Deposit yRSS.  
Second: Phase C the moment yRSS source depth clears a real pull.  
Third: Phase D the moment hot can fund repayRail at the size the King wants Cake to hold.  
Fourth: Phase E scales when foreign maxIn opens — same scripts.  
Always: Phase A and F.

## Kill list
Do not ask the King for a new architecture. Do not send ops USDC into Cake. Do not call circular flash self-lend “vault fill.” Do not sit on Gauntlet as step zero. Do not build a Cake withdrawal backdoor.

## Ready rails (already in repo)
FirePositionSeed700k, CrownSpoilFire, CrownCrossFlash (repayRail = hot), curator packet, SetPa700k, oracle $1, PoD live.

## One sentence for the crown
Fund yRSS and/or repayRail from King hot; execute reallocate+borrow or CrossFlash; Cake eats; foreign PA only multiplies what we already engineered.
