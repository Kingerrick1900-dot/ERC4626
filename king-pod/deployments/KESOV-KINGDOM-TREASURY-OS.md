# KESOV Kingdom Treasury OS — DOCTRINE

**Play:** Make **eUSD bigger than ELE**.

Any hard asset the Kingdom holds — ELE, kXAU, WETH, cbBTC — **mints eUSD**.  
eUSD **exits to USDC** through a PSM.  
**Morpho** is the leverage engine on top — not the mint path.

That is how eUSD stops being “Elepan’s internal dollar” and becomes an overcollateralized stable that can survive outside the empire.

```
[ ELE | kXAU | WETH | cbBTC ]
            │  mint (CDP)
            ▼
          eUSD
            │  redeem (PSM)
            ▼
          USDC  ←── ops / settlement / outside empire
            ▲
            │  leverage (supply/borrow)
         Morpho
```

## Three layers (locked)

| Layer | Job | Not its job |
|-------|-----|-------------|
| **1. Multi-asset CDP** | Lock coll → mint eUSD | Sell ELE for USDC |
| **2. PSM** | eUSD ↔ USDC (and gold parity on Scroll) | Replace CDP collateral |
| **3. Morpho** | Leverage / idle / PA pipes in USDC | Source of eUSD supply |

ELE remains **sovereign collateral**. It is not the exit plan.  
External coll (WETH, cbBTC, gold) is what makes eUSD **bigger than ELE**.

## Live vs missing

### Layer 1 — mint eUSD

| Coll | Chain | Status | Note |
|------|-------|--------|------|
| **ELE** | Base | LIVE | Kingdom ELE CDP + ELE/eUSD pool |
| **WETH** | Base | LIVE | CDP `0x60033c198bb686cEA1BAAF5a5CDc7b6e3Ddc9BCF` |
| **cbBTC** | Base | LIVE | CDP `0xb7Be10165c7A3296Cb621478B3dD497c65Da28d5` |
| **kXAU** | Scroll | LIVE | Gold CDP (100,001 kXAU book) |

Shared Base eUSD (multi-minter): `0xE8aAD0DDdB2E856183C8417654bfBF9e507Caf8a`.

### Layer 2 — PSM exit

| Rail | Chain | Status | Gap |
|------|-------|--------|-----|
| **Gold Parity PSM** | Scroll | LIVE | Depth still dust — capitalize before public force-to-$1 |
| **eUSD Link** Base↔Scroll | Both | LIVE | Bridge into Scroll redeem |
| **Base USDC PSM** | Base | **MISSING** | Hard USDC exit on Base without Scroll hop |

Gold redeem stays **Scroll-native**. Base holds the link leg today.

### Layer 3 — Morpho leverage

| Book | Status | Role under this OS |
|------|--------|--------------------|
| ELE77 / USDC | LIVE | Leverage on ELE coll — borrows **USDC**, does not mint eUSD |
| WETH/USDC · cbBTC/USDC (yELE/yRSS PA) | LIVE / gated | Liquidity pipes into Morpho idle — still not eUSD mint |

Morpho amplifies **USDC balance-sheet**. CDPs grow **eUSD float**.

## North-star test

eUSD is bigger than ELE when:

1. Material eUSD supply is backed by **WETH / cbBTC / kXAU**, not only ELE.  
2. Anyone can redeem eUSD → USDC through a **capitalized PSM** (not a thin DEX mark).  
3. Morpho can lever the USDC sleeve without being the only path to dollars.

## Build order (King-gated fire only)

1. **Capitalize Scroll Gold PSM** — real USDC + free kXAU (not CDP gold).  
2. **Keeper buy-bridge-redeem** — Base discount → link → Scroll `redeemUsdc` / `redeemKxau`.  
3. **Base USDC PSM** — same doctrine, home-chain exit.  
4. **Scale WETH/cbBTC CDPs** — mint eUSD against external coll; ELE share of float falls.  
5. **Morpho** — draw / PA only when idle exists; never confuse borrow headroom with PSM depth.

## Control plane

`kesov-repos/kesov-treasury-os` = Accounting → Policy → Risk → Intent → Sentinel.  
Bots submit Intents. Sentinel pauses. Unwinds need King sig.  
That OS **operates** this stack; it does not replace the mint / PSM / Morpho layers above.

## Doctrine locks

- eUSD grows by **adding coll types**, not by selling ELE.  
- PSM before arb theater — empty PSM is not a peg.  
- Morpho ≠ mint. CDP ≠ Morpho borrow.  
- Gold rail on Scroll; Base link until a Base gold/USDC PSM is ordered.  
- Goal line: **eUSD float >> ELE-only backing.**
