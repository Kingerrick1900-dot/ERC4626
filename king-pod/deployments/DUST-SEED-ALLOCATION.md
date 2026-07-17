# Dust seed allocation — optics / missing wallets

Same energy as dust cbBTC + USDC that grew the token. Seeds in wallets. **No Play 3 borrow** — left visible.

## Source
Token/hot `0x6708…` had **8,171,102** USDC + **1,849** cbBTC dust.

## Allocation (raw)

| Destination | USDC | cbBTC | Why |
|-------------|------|-------|-----|
| Cake `0xA1aF…` | **4,000,000** ($4.00) | **1,000** | Lender-facing vault wallet |
| Morpho RSS market idle | **1,500,000** ($1.50) | — | Market shows liquidity (supply only) |
| yRSS vault TVL | **1,000,000** ($1.00) | — | `totalAssets` = 1e6 |
| Desk `0x831b…` | **100,000** ($0.10) | — | Desk dust |
| Fleet `0xcbD8…` | **100,000** ($0.10) | — | Strike dust |
| Hot (kept) | **~1,471,102** ($1.47) | **849** | Seed stays at source |

## Final snapshot
- hot USDC **1,471,102** · cbBTC **849**
- cake USDC **4,000,000** · cbBTC **1,000**
- market idle **1,500,000**
- yRSS totalAssets **1,000,000**
- desk / fleet **100,000** each

## Note
yRSS contract USDC balance can read 0 — assets sit allocated in Morpho; `totalAssets` is the lender-visible number.
