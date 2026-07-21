# OUTBOUND — Spoils Rails (copy/send)

**King Errick of Yahudah · Kingdom RSS · Base**

Four live rails. Same asset. Same Landing settlement. Pick peg, fixed discount, Dutch urgency, or whale rebate.

---

## Copy block (Telegram / DM / email)

```
Kingdom RSS — Base — four live settlement rails

ASSET
RSS 0x7a305D07B537359cf468eAea9bb176E5308bC337
Morpho FixedOracle $1 (owner burned): 0x284EC3A9674e6C62ea552Bf75BDeE9B799627D2e
Morpho Blue RSS/USDC: 0x40ac09f34c5bc0b0b6d9b5f1ec1b97a6a149ff6278104797c9cb740453a2b794

PROOF
$9M borrow opened and repaid. Morpho position ZERO (no debt):
https://basescan.org/tx/0x453b51c6511266d274d257e62c1d00d83f6389d50cdeccb2806aeaf9245de635

RAIL A — DESK @ $1.00 (700k RSS live)
Desk:     0xDbf7C4Ad01418ec1b753fa039d5e5B54aF4C065D
Helper:   0xeA454FAD0115A8131C3E10bC117A6584f649356b
Fill:     approve USDC → helper.fillPhase1() for $500k
          or desk.buyWithUsdc(amount)
Proceeds: Landing 0x5Adcea5319eA9Eac1241B95Ca53690574cFa2357

RAIL B — BOND @ $0.97 (520k RSS live, 3% discount)
Bond:     0x2D743eF8bf8eE188F44239Acc1e4795fe8cA3039
Fill:     approve USDC → bond.bondWithUsdc(amount)
$500k ≈ 515,464 RSS at $0.97
Proceeds: same Landing

RAIL C — DUTCH @ $0.94→$0.99 (500k RSS live, price rises daily)
Dutch:    0x8A4C17c5FAB0ba334dAe4CdECa8BaC60a8Cc5E81
Fill:     approve USDC → dutch.bondWithUsdc(amount)
Now:      currentPrice() on Basescan — early = deeper discount
Proceeds: same Landing

RAIL D — FIRST WHALE (50k RSS rebate for ≥$500k yRSS deposit)
Whale:    0xC33256BCb972db576d116D5Ca5B56A8B457337E8
Fill:     approve USDC → whale.depositAsWhale(amount) until ≥$500k cumulative
          then whale.claimRebate() for 50k RSS
Creates yRSS TVL; Kingdom captures idle → borrow → Landing after fill.

USDC Base: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
Spoils router (King sweep): 0xF7B90BE47fa67100dF91ea6E52C588063d1E5bE0

Not a fundraise. Not a loan. On-chain asset sale. Atomic settlement.
Reply with size or fill direct on Basescan.
```

---

## Short ping (Twitter / public)

```
RSS on Base — four live OTC rails:
• $1.00 desk (700k) — 0xDbf7C4Ad01418ec1b753fa039d5e5B54aF4C065D
• $0.97 bond (520k) — 0x2D743eF8bf8eE188F44239Acc1e4795fe8cA3039
• Dutch $0.94→$0.99 (500k) — 0x8A4C17c5FAB0ba334dAe4CdECa8BaC60a8Cc5E81
• First Whale 50k RSS rebate — 0xC33256BCb972db576d116D5Ca5B56A8B457337E8
Morpho-proven collateral. Zero kingdom debt. USDC → cold Landing. DM for size.
```

---

## Attachments

| Doc | Use |
|-----|-----|
| `OPS-COUNTERPARTY-PACKET.md` | Desk @ $1 full terms |
| `BOND-COUNTERPARTY-PACKET.md` | Bond @ $0.97 full terms |
| `POST-ZERO-PLAYS.md` | Internal play board |

---

## After first fill

Run `bash script/plays-status.sh` — Landing balance + raised meters.  
King orders: yRSS re-seed · credit line re-arm when idle faces book.
