# FIRE — Sovereign Credit Bridge (Killer PAR → KRT)

**Mode:** FIRE · Base · **LIVE**  
**Doctrine:** Mint KRT against Killer PAR RSS (200% OC) · Ocean KRT/USDC door · yRSS stays USDC-only

## Live addresses

| Piece | Address |
|--|--|
| CrownSovereignCredit | `0xd220325520c7051343e811dB99f47A43685EA44E` |
| CrownKRT (bridge) | `0x2d4FA9D3daCFA8e20A421cd7C232Ffaa33DadFAA` |
| CrownSovereignColdKrt | `0xfD96B66dA8Aa0DA6434aD4D66926D584DBFc1517` |
| KRT/USDC Aerodrome pool | `0xEA4504CbA4107638Dda7Aa5E0EBF11Ec0d8FC4E8` |
| Collateral | Killer `0x7273…` PAR · ~222,521.94 RSS |

## Mint

| | |
|--|--:|
| Minted | **30,000,000 KRT** |
| HOT (80%) | **24,000,000** |
| Cold (20%) | **6,000,000** |
| Max mint @ 200% OC | ~5.56e27 wei (~$5.56T notional headroom) |

## Bridge corrections vs handoff

- **Elephant bypassed** — capacity reads Killer PAR RSS.
- **yRSS not seeded with KRT** — vault `asset=USDC`; Ocean pool is the door.
- **USDC pool seed / Nigeria / allocator raid** — blocked until real USDC inventory exists (HOT USDC=0).

## Pre-reqs fired

| Step | Hash |
|--|--|
| Prove Safe (TTL refresh) | see broadcast `FireZkProveSafe` |
| Prove HOT (TTL refresh) | see broadcast `FireZkWalletRefresh` |
| Credit + mint + pool | see broadcast `FireSovereignCreditBridge` |
