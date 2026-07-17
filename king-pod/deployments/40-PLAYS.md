# 40 PLAYS — Kingdom revenue / liquidity / fee engineering

No seed homework. No “wait for users.” Plays only.

## MEV / Strike (legal Morpho design)
1. **Base Morpho HF<1 strike** — flash liquidate cbBTC/WETH/USDC books → profit KingVault  
2. **Partial liquidation sizing** — skim bonus without full close; more hits  
3. **Multi-relay fanout** — Flashbots/Titan/bloXroute style private submit on Base relays that exist  
4. **Pre-liq backrun queue** — hold sim while HF>1, fire same block HF crosses 1  
5. **Oracle update backrun** — liquidate in same block as price move (Morpho oracle touch)  
6. **Vault share redeem liquidations** — seize MetaMorpho collateral shares → redeem → USDC  
7. **Cross-market liquidator** — one bot, all Base Morpho USDC loan markets  
8. **Strike fee skimming via CrownFlashRouter** — every liq flash pays 30 bps to vault  

## Issuer / Peapods-style (fork elite self-lend)
9. **RSS=$1 oracle + flash self-lend** — 100% util Proof-of-Demand book (Peapods POD pattern)  
10. **High-util rate magnet** — AdaptiveCurve IRM at max util advertises yield to PA vaults  
11. **Quiet scaler** — auto add RSS collateral + flash expand book when RSS free  
12. **Self-deleverage on HF floor** — keep book alive, never free-liq yourself  
13. **Circular book → real borrow** — when PA maxIn opens, replace self-supply with external USDC, keep debt to vault  

## yRSS curator games (King owns the vault)
14. **Multi-market yRSS** — allocate to cbBTC/USDC + WETH/USDC + RSS (yield harvester, 10% fee)  
15. **Idle market park** — zero-collateral USDC pocket for instant withdraws / PA bait  
16. **PA-enabled yRSS** — King vault becomes JIT liquidity source; fee on flow  
17. **Cap ladder** — raise RSS cap in steps $100k→$700k→$14M as book proves  
18. **Performance fee harvest cron** — force accrue + skim to KingVault on timer  
19. **Curator reallocate arb** — move yRSS between Morpho markets when APY spreads  

## Public Allocator / vault politics (create the pipe)
20. **Steakhouse listing fork** — copy risk params of listed exotic markets they already approved  
21. **Gauntlet listing fork** — same  
22. **Morpho forum / Discord curator packet blast** — one PDF, four vaults, $700k maxIn ask  
23. **List RSS on King’s yRSS FIRST** — then ask big vaults to mirror King’s own allocation  
24. **Flow-cap watcher → auto fire borrow** — no human delay when maxIn flips  

## Flash fee / infrastructure monetization
25. **CrownFlashRouter as Base Morpho flash retail** — 30 bps, KingVault treasury, publish ABI only to bots  
26. **Whitelist operator desks** — permissioned flash users who pay fee (not public retail)  
27. **Bundler3 adapter** — wrap Crown router into Morpho bundler so integrators pay fee in-path  
28. **Fee rebate for volume** — 30 bps headline / 10 bps for loyal ops (sticky flow)  

## Trapped capital / V1 surgery
29. **V1 bytecode autopsy deep** — every selector, any owner path to free LP  
30. **V1 repay-$1 probe** — if any dust USDC path unlocks LP accounting  
31. **Fresh V3 market + migrate narrative** — new market with releaseCollateral; socialize exit story for LP  
32. **Pair RSS as future collateral** — if LP exit ever works, 21B RSS becomes borrow power  

## Liquid RSS / desk / inventory plays
33. **Rescue desk 5.5k RSS → hot** — immediate  
34. **Kill dust elite-close** — stop burning RSS for pennies  
35. **Desk as OTC fill for Strike swaps** — RSS/USDC inventory for seized-asset routes  
36. **Fixed $1 desk price** — issuer fill rail matches oracle for closes  

## Creative forks (other protocols’ moves)
37. **Usual/Ethena-style issuer credit** — RSS as sovereign unit of account inside Kingdom only  
38. **Contango one-click leverage wrapper** — flash open RSS/USDC position for King in one click  
39. **Merkl / incentive listing** — farm points on RSS market supply to bribe first external USDC  
40. **Telegram Strike command → vault sweep** — every profitable fire auto-routes USDC to KingVault same tx  

## Execute order (worker)
A. Arm Strike → KingVault + Crown fee on flash  
B. ArmKingdomFees (router 30 bps + yRSS recipient vault)  
C. Multi-market yRSS caps (cbBTC + WETH + RSS)  
D. Oracle $1 + self-lend book (PoD)  
E. Curator packets out  
F. Desk rescue + kill dust fires  

Greenlight = start A–F in parallel.
